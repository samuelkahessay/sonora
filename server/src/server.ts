import express from 'express';
import cors from 'cors';
import multer from 'multer';
import { z } from 'zod';
import fs from 'fs';
import { FormData, File } from 'undici';
import { RequestSchema, AnalysisDataSchema, DistillDataSchema, ThemesDataSchema, TodosDataSchema, EventsDataSchema, RemindersDataSchema, ModelSettings, AnalysisJsonSchemas } from './schema.js';
import { buildPrompt } from './prompts.js';
import { createChatJSON, createModeration } from './openai.js';
import { sanitizeTranscript } from './sanitize.js';

const app = express();
const PORT = process.env.PORT || 8080;
const CORS_ORIGIN = process.env.CORS_ORIGIN || 'https://sonora.app';
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY;

// Ensure uploads directory exists (defensive)
try {
  fs.mkdirSync('uploads', { recursive: true });
} catch (error: any) {
  if (error.code !== 'EEXIST') {
    console.warn('Could not create uploads directory:', error.message);
  }
}
const upload = multer({ dest: 'uploads/' });

// Security headers
app.disable('x-powered-by');
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  next();
});

// CORS
app.use(cors({
  origin: CORS_ORIGIN,
  credentials: false
}));

// Body parser with size limit
app.use(express.json({ limit: '256kb' }));

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok' });
});

// Legacy health check for Fly.io
app.get('/health', (req, res) => {
  res.json({ ok: true });
});

// Title generation (OpenRouter: llama free)
const TitleRequest = z.object({
  transcript: z.string().min(1).max(100_000),
  language: z.string().optional(),
  rules: z.object({
    words: z.string().optional(),
    titleCase: z.boolean().optional(),
    noPunctuation: z.boolean().optional(),
    maxChars: z.number().optional()
  }).optional()
});

function sliceForTitle(text: string): string {
  const maxFirst = 1500; const maxLast = 400;
  if (text.length <= maxFirst) return text;
  const first = text.slice(0, maxFirst);
  const last = text.slice(-maxLast);
  return `${first}\n\n${last}`;
}

function normalizeWhitespace(s: string): string {
  return s.replace(/\s+/g, ' ').trim();
}

function stripSoftPunctuation(s: string): string {
  return s
    // remove lightweight punctuation and quotes entirely
    .replace(/["'“”‘’,.!?;:]+/gu, ' ')
    // collapse stray hyphen/• between words
    .replace(/[•·]+/gu, ' ');
}

function hasEmojiOrPunct(s: string): boolean {
  // Reject punctuation and emoji presentation characters
  const punctOrEmoji = /[\p{P}\p{Emoji_Presentation}]/u;
  return punctOrEmoji.test(s);
}

function isNoSpaceLanguage(language?: string): boolean {
  if (!language) return false;
  const normalized = language.toLowerCase();
  return normalized.startsWith('ja') || normalized.startsWith('zh') || normalized.startsWith('ko');
}

function validateTitle(
  raw: string,
  {
    maxChars = 32,
    language,
    isShortTranscript = false
  }: { maxChars?: number; language?: string; isShortTranscript?: boolean } = {}
): string | null {
  let cleaned = normalizeWhitespace(raw.replace(/\n/g, ' '));
  if (!cleaned) return null;
  cleaned = normalizeWhitespace(stripSoftPunctuation(cleaned));
  if (!cleaned) return null;
  if (cleaned.length > maxChars) return null;

  if (hasEmojiOrPunct(cleaned)) return null;

  const words = cleaned.split(' ').filter(Boolean);
  const noSpaceLang = isNoSpaceLanguage(language);
  const minWords = noSpaceLang ? 1 : (isShortTranscript ? 2 : 3);
  const maxWords = noSpaceLang ? 6 : 5;
  if (words.length < minWords || words.length > maxWords) return null;

  return cleaned;
}

function buildFallbackTitle(source: string): string {
  const sanitized = normalizeWhitespace(stripSoftPunctuation(source));
  if (!sanitized) return 'Voice Memo';
  const words = sanitized.split(' ').filter(Boolean);
  if (words.length === 0) return 'Voice Memo';
  const snippet = words.slice(0, Math.min(words.length, 5)).map(word => {
    if (word.length === 0) { return word; }
    const [first, ...rest] = word;
    return first.toUpperCase() + rest.join('').toLowerCase();
  }).join(' ');
  const truncated = snippet.slice(0, 32).trim();
  return truncated || 'Voice Memo';
}

app.post('/title', async (req, res) => {
  try {
    const { transcript, language, rules } = TitleRequest.parse(req.body || {});
    if (!OPENROUTER_API_KEY) {
      return res.status(500).json({ error: 'Server missing OPENROUTER_API_KEY' });
    }

    const sanitized = sanitizeTranscript(String(transcript));
    const sliced = sliceForTitle(sanitized);
    const isShortTranscript = sliced.trim().length < 80;
    const constraints = {
      words: (rules?.words || '3-5'),
      titleCase: rules?.titleCase ?? true,
      noPunctuation: rules?.noPunctuation ?? true,
      maxChars: rules?.maxChars ?? 32
    };

    const system = [
      'You generate concise, high-quality titles for personal wellness notes.',
      'Return ONLY the title, no quotes, no punctuation/emojis, no extra words.',
      'Respect the transcript language. Keep it 3–5 words, Title Case, ≤32 chars.'
    ].join(' ');

    const user = [
      language ? `Language hint: ${language}` : undefined,
      `Rules: ${constraints.words} words, Title Case=${constraints.titleCase}, No Punctuation=${constraints.noPunctuation}, MaxChars=${constraints.maxChars}.`,
      'Transcript:',
      sliced
    ].filter(Boolean).join('\n');

    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': process.env.SONORA_SITE_URL || 'https://sonora.app',
        'X-Title': process.env.SONORA_SITE_NAME || 'Sonora'
      },
      body: JSON.stringify({
        model: 'meta-llama/llama-3.3-8b-instruct:free',
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user }
        ],
        temperature: 0.2,
        max_tokens: 32
      })
    });

    if (!response.ok) {
      const text = await response.text().catch(() => '');
      console.error('OpenRouter /title error:', response.status, response.statusText, text.slice(0, 200));
      return res.status(502).json({ error: 'UpstreamFailed' });
    }
    const data: any = await response.json();
    const content: string = data?.choices?.[0]?.message?.content ?? '';
    const candidate = normalizeWhitespace(content.replace(/\n/g, ' '));
    const validated = validateTitle(candidate, {
      maxChars: constraints.maxChars,
      language,
      isShortTranscript
    });
    if (validated) {
      return res.json({ title: validated });
    }

    console.warn('Title validation failed; using fallback', {
      candidate,
      maxChars: constraints.maxChars,
      language,
      isShortTranscript
    });

    const fallback = validateTitle(buildFallbackTitle(sliced), {
      maxChars: constraints.maxChars,
      language,
      isShortTranscript: true
    }) || 'Voice Memo';

    return res.json({ title: fallback, fallback: true });
  } catch (e: any) {
    if (e instanceof z.ZodError) {
      return res.status(400).json({ error: 'BadRequest', details: e.errors });
    }
    console.error('Title generation error:', e?.message || String(e));
    return res.status(500).json({ error: 'Internal' });
  }
});

// Transcription endpoint (existing functionality)
app.post('/transcribe', upload.single('file'), async (req, res) => {
  try {
    if (!OPENAI_API_KEY) {
      return res.status(500).json({ error: 'Server missing OPENAI_API_KEY' });
    }
    
    if (!req.file) {
      return res.status(400).json({ error: 'file missing' });
    }

    const form = new FormData();
    const fileBuffer = fs.readFileSync(req.file.path);
    const file = new File([fileBuffer], req.file.originalname || 'audio.m4a', { type: 'audio/m4a' });
    form.append('file', file);
    form.append('model', 'whisper-1');
    // Optional language hint from client (ISO 639-1 or BCP-47)
    const langRaw = (req.body?.language as string | undefined)?.trim();
    if (langRaw) {
      console.log('[transcribe] language hint =', langRaw);
    }
    if (langRaw && langRaw.length > 0) {
      form.append('language', langRaw);
    }
    // Ask for richer metadata so client can evaluate quality
    form.append('response_format', 'verbose_json');
    // Ensure we transcribe in-source language (not translate to English)
    form.append('translate', 'false');
    // Stabilize output a bit
    form.append('temperature', '0');

    // Optional biasing prompt to reinforce language for short clips
    // This helps languages that Whisper may mis-detect on brief audio
    const PROMPTS: Record<string, string> = {
      es: 'Idioma: español. Transcribe en español, sin traducir. ¿Qué tal? ¡Gracias!',
      zh: '语言：中文。请用中文转写，不要翻译。谢谢。',
      ja: '言語：日本語。翻訳せずに日本語で書き起こしてください。',
      ko: '언어: 한국어. 번역하지 말고 한국어로만 전사해주세요.',
      fr: 'Langue : français. Transcrivez en français, sans traduire. Merci.',
      de: 'Sprache: Deutsch. Bitte auf Deutsch transkribieren, ohne zu übersetzen.',
      am: 'ቋንቋ፡ አማርኛ። እባክዎ ትርጉም ሳይሰጡ በአማርኛ ብቻ ይተክቱ። እናመሰግናለን።',
      ar: 'اللغة: العربية. يرجى النسخ بالعربية دون ترجمة. شكراً.',
      // Additional frequently used languages
      ru: 'Язык: русский. Транскрибируйте на русском, без перевода. Спасибо.',
      pt: 'Idioma: português. Transcreva em português, sem traduzir. Obrigado.',
      it: 'Lingua: italiano. Trascrivere in italiano, senza tradurre. Grazie.',
      hi: 'भाषा: हिंदी। कृपया हिंदी में ट्रांसक्राइब करें, अनुवाद न करें। धन्यवाद।',
      nl: 'Taal: Nederlands. Transcribeer in het Nederlands, zonder te vertalen. Dank je.',
      pl: 'Język: polski. Transkrybuj po polsku, bez tłumaczenia. Dziękuję.',
      tr: 'Dil: Türkçe. Lütfen Türkçe olarak yazıya dökün, çevirmeyin. Teşekkürler.',
      vi: 'Ngôn ngữ: tiếng Việt. Vui lòng phiên âm bằng tiếng Việt, không dịch. Cảm ơn.',
      sv: 'Språk: svenska. Transkribera på svenska, utan att översätta. Tack.',
      uk: 'Мова: українська. Транскрибуйте українською, без перекладу. Дякую.',
      he: 'שפה: עברית. אנא תמלל בעברית, ללא תרגום. תודה.',
      el: 'Γλώσσα: ελληνικά. Μεταγράψτε στα ελληνικά, χωρίς μετάφραση. Ευχαριστώ.',
    };
    if (langRaw && PROMPTS[langRaw]) {
      form.append('prompt', PROMPTS[langRaw]);
    }

    async function callOpenAI(f: FormData) {
      return await fetch('https://api.openai.com/v1/audio/transcriptions', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${OPENAI_API_KEY}` },
        body: f
      });
    }

    let response = await callOpenAI(form);
    let data = await response.json() as any;

    // Cleanup temp file
    fs.unlink(req.file.path, () => {});

    if (!response.ok) {
      const message: string | undefined = data?.error?.message || data?.message;
      const unsupportedLang = (message && langRaw)
        ? message.toLowerCase().includes('language') && message.toLowerCase().includes('not supported')
        : false;

      if (unsupportedLang && langRaw) {
        // Retry once without the language parameter but keep the bias prompt
        const form2 = new FormData();
        form2.append('file', file);
        form2.append('model', 'whisper-1');
        form2.append('response_format', 'verbose_json');
        form2.append('translate', 'false');
        form2.append('temperature', '0');
        if (PROMPTS[langRaw]) { form2.append('prompt', PROMPTS[langRaw]); }
        console.warn(`[transcribe] Retrying without language (unsupported: ${langRaw})`);
        response = await callOpenAI(form2);
        data = await response.json();
      }

      if (!response.ok) {
        // Avoid logging upstream bodies; emit minimal error context
        const message = data?.error?.message || data?.message || 'transcription failed';
        console.error('OpenAI transcription error:', { status: response.status, message });
        return res.status(response.status).json({ 
          error: message 
        });
      }
    }

    // Aggregate avg_logprob across segments if present
    let avg_logprob: number | undefined = undefined;
    if (Array.isArray(data?.segments) && data.segments.length > 0) {
      const vals = data.segments
        .map((s: any) => (typeof s?.avg_logprob === 'number' ? s.avg_logprob : undefined))
        .filter((n: number | undefined) => typeof n === 'number') as number[];
      if (vals.length > 0) {
        avg_logprob = vals.reduce((a, b) => a + b, 0) / vals.length;
      }
    }
    // Derive a soft confidence from avg_logprob in [-2, 0] -> [0, 1]
    let confidence: number | undefined = undefined;
    if (typeof avg_logprob === 'number') {
      const norm = (avg_logprob + 2.0) / 2.0; // [-2,0] -> [0,1]
      confidence = Math.max(0, Math.min(1, norm));
    }

    // Trace detection details for diagnostics
    const detectedLang = typeof data?.language === 'string' ? data.language : undefined;
    const dur = typeof data?.duration === 'number' ? data.duration : undefined;
    const segCount = Array.isArray(data?.segments) ? data.segments.length : 0;
    try {
      console.log(
        `[transcribe] detected_language=${detectedLang ?? 'und'} avg_logprob=${
          typeof avg_logprob === 'number' ? avg_logprob.toFixed(3) : 'n/a'
        } confidence=${typeof confidence === 'number' ? confidence.toFixed(3) : 'n/a'} duration=${
          typeof dur === 'number' ? dur.toFixed(2) : 'n/a'
        } segments=${segCount}`
      );
    } catch {}

    res.json({ 
      text: data.text ?? '',
      detected_language: detectedLang ?? undefined,
      avg_logprob,
      confidence,
      duration: typeof data.duration === 'number' ? data.duration : undefined
    });
  } catch (error: any) {
    console.error('Transcription error:', error);
    res.status(500).json({ error: 'server error' });
  }
});

// Main analyze endpoint
app.post('/analyze', async (req, res) => {
  const startTime = Date.now();
  
  try {
    // Validate request
    const { mode, transcript } = RequestSchema.parse(req.body);
    
    // Build prompts
    const { system, user } = buildPrompt(mode, transcript);
    
    // Get GPT-5 settings for this mode
    const settings = ModelSettings[mode as keyof typeof ModelSettings] || { verbosity: 'low', reasoningEffort: 'medium' };
    const schema = AnalysisJsonSchemas[mode as keyof typeof AnalysisJsonSchemas];
    const { jsonText, usage } = await createChatJSON({
      system,
      user,
      verbosity: settings.verbosity,
      reasoningEffort: settings.reasoningEffort,
      schema
    });
    
    // Parse and repair JSON if needed
    let parsedData;
    try {
      parsedData = JSON.parse(jsonText);
    } catch {
      // Best-effort repair: strip leading/trailing non-JSON chars
      const stripped = jsonText.trim().replace(/^[^{]*/, '').replace(/[^}]*$/, '');
      try {
        parsedData = JSON.parse(stripped);
      } catch {
        return res.status(502).json({
          error: 'UpstreamFailed',
          message: 'Invalid JSON from OpenAI'
        });
      }
    }
    
    // Validate response shape
    let validatedData;
    try {
      switch (mode) {
        case 'analysis':
          validatedData = AnalysisDataSchema.parse(parsedData);
          break;
        case 'distill':
          validatedData = DistillDataSchema.parse(parsedData);
          break;
        case 'distill-summary':
          validatedData = { summary: parsedData.summary };
          break;
        case 'distill-actions':
          validatedData = { action_items: parsedData.action_items || [] };
          break;
        case 'distill-themes':
          validatedData = { key_themes: parsedData.key_themes || [] };
          break;
        case 'distill-reflection':
          validatedData = { reflection_questions: parsedData.reflection_questions || [] };
          break;
        case 'themes':
          validatedData = ThemesDataSchema.parse(parsedData);
          break;
        case 'todos':
          validatedData = TodosDataSchema.parse(parsedData);
          break;
        case 'events':
          validatedData = EventsDataSchema.parse(parsedData);
          break;
        case 'reminders':
          validatedData = RemindersDataSchema.parse(parsedData);
          break;
        default:
          throw new Error(`Unknown mode: ${mode}`);
      }
    } catch (schemaError) {
      return res.status(502).json({
        error: 'SchemaMismatch',
        details: schemaError instanceof z.ZodError ? schemaError.errors : 'Schema validation failed'
      });
    }
    
    // Build a compact text sample for moderation
    let textForModeration = '';
    try {
      const vd: any = validatedData as any;
      switch (mode) {
        case 'analysis':
          textForModeration = `${vd.summary}\n${(vd.key_points || []).join(' \n')}`;
          break;
        case 'distill':
          textForModeration = `${vd.summary}\n${(vd.action_items || []).map((a: any) => a.text).join(' \n')}\n${(vd.reflection_questions || []).join(' \n')}`;
          break;
        case 'distill-summary':
          textForModeration = vd.summary || '';
          break;
        case 'distill-actions':
          textForModeration = (vd.action_items || []).map((a: any) => a.text).join(' \n');
          break;
        case 'distill-themes':
          textForModeration = (vd.key_themes || []).join(' \n');
          break;
        case 'distill-reflection':
          textForModeration = (vd.reflection_questions || []).join(' \n');
          break;
        case 'themes':
          textForModeration = `${vd.sentiment}\n${vd.themes.map((t: any) => `${t.name}: ${(t.evidence || []).join(' ')}`).join(' \n')}`;
          break;
        case 'todos':
          textForModeration = `${vd.todos.map((t: any) => t.text).join(' \n')}`;
          break;
        case 'events':
          textForModeration = `${(vd.events || []).map((e: any) => `${e.title} ${e.location || ''}`).join(' \n')}`;
          break;
        case 'reminders':
          textForModeration = `${(vd.reminders || []).map((r: any) => r.title).join(' \n')}`;
          break;
      }
    } catch {}
    const moderation = await createModeration(String(textForModeration || '').slice(0, 8000));
    
    const latency = Date.now() - startTime;
    
    // Return canonical response
    res.json({
      mode,
      data: validatedData,
      model: process.env.SONORA_MODEL || 'gpt-5-nano',
      tokens: {
        input: usage.input,
        output: usage.output,
        ...(usage.reasoning !== undefined && { reasoning: usage.reasoning })
      },
      latency_ms: latency,
      moderation
    });
    
  } catch (error: any) {
    const latency = Date.now() - startTime;
    
    // Handle validation errors
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: 'BadRequest',
        details: error.errors
      });
    }
    
    // Handle upstream failures with retry info
    if (error.retryCount !== undefined) {
      return res.status(502).json({
        error: 'UpstreamFailed',
        retryCount: error.retryCount,
        latency_ms: latency
      });
    }
    
    // Generic server error
    console.error('Server error:', error.message);
    res.status(500).json({
      error: 'Internal',
      latency_ms: latency
    });
  }
});

app.get('/keycheck', async (_req, res) => {
  try {
    if (!OPENAI_API_KEY) return res.status(500).json({ ok: false, message: 'OPENAI_API_KEY missing' });
    
    const startTime = Date.now();
    const { jsonText, usage } = await createChatJSON({
      system: 'You are a GPT-5-nano validation service. Respond with valid JSON exactly as requested.',
      user: 'Respond with this JSON object: {"ok":true,"model":"gpt-5-nano","test":"keycheck"}',
      verbosity: 'low',
      reasoningEffort: 'low'
    });
    const responseTime = Date.now() - startTime;
    
    const parsed = JSON.parse(jsonText);
    const isValid = !!parsed?.ok;
    
    return res.json({ 
      ok: isValid, 
      message: isValid ? 'GPT-5-nano key valid' : 'Invalid response from GPT-5-nano',
      model: process.env.SONORA_MODEL || 'gpt-5-nano',
      performance: {
        responseTime: `${responseTime}ms`,
        tokens: {
          input: usage.input,
          output: usage.output,
          ...(usage.reasoning && { reasoning: usage.reasoning })
        }
      },
      raw: parsed 
    });
  } catch (e: any) {
    console.error('🚨 Keycheck failed:', e?.message);
    return res.status(502).json({ 
      ok: false, 
      message: `GPT-5-nano test failed: ${e?.message || 'Unknown error'}`,
      model: process.env.SONORA_MODEL || 'gpt-5-mini'
    });
  }
});

app.get('/test-gpt5', async (_req, res) => {
  try {
    if (!OPENAI_API_KEY) {
      return res.status(500).json({ 
        success: false, 
        message: 'OPENAI_API_KEY missing',
        tests: []
      });
    }

    const testTranscript = "Today I had a productive meeting about the new project. We discussed the timeline and budget concerns. I need to follow up with Sarah by Friday about the proposal, and remember to call the client tomorrow at 2pm to discuss the contract details. The team seemed optimistic about hitting our Q2 targets.";
    
    const testResults = [];
    const overallStartTime = Date.now();
    
    // Test all analysis modes
    const modes = ['distill', 'distill-summary', 'distill-actions', 'distill-themes', 'distill-reflection', 'analysis', 'themes', 'todos', 'events', 'reminders'] as const;
    
    for (const mode of modes) {
      const testStartTime = Date.now();
      try {
        console.log(`🧪 Testing GPT-5-nano mode: ${mode}`);
        
        // Get settings and schema for this mode
        const settings = ModelSettings[mode] || { verbosity: 'low', reasoningEffort: 'medium' };
        const schema = AnalysisJsonSchemas[mode];
        const { system, user } = buildPrompt(mode, testTranscript);
        
        const { jsonText, usage } = await createChatJSON({
          system,
          user,
          verbosity: settings.verbosity,
          reasoningEffort: settings.reasoningEffort,
          schema
        });
        
        const responseTime = Date.now() - testStartTime;
        
        // Validate JSON structure
        let parsedData;
        let validationResult: { valid: boolean; error: string | null; keys: string[] } = { valid: false, error: null, keys: [] };
        
        try {
          parsedData = JSON.parse(jsonText);
          validationResult.valid = true;
          validationResult.keys = Object.keys(parsedData);
          
          // Basic schema validation based on mode
          switch (mode) {
            case 'distill':
              validationResult.valid = !!(parsedData.summary && parsedData.key_themes && parsedData.reflection_questions);
              break;
            case 'distill-summary':
              validationResult.valid = !!(parsedData.summary);
              break;
            case 'distill-actions':
              validationResult.valid = Array.isArray(parsedData.action_items);
              break;
            case 'distill-themes':
              validationResult.valid = Array.isArray(parsedData.key_themes);
              break;
            case 'distill-reflection':
              validationResult.valid = Array.isArray(parsedData.reflection_questions);
              break;
            case 'analysis':
              validationResult.valid = !!(parsedData.summary && parsedData.key_points);
              break;
            case 'themes':
              validationResult.valid = !!(parsedData.themes && parsedData.sentiment);
              break;
            case 'todos':
              validationResult.valid = !!(parsedData.todos);
              break;
          }
        } catch (jsonError: any) {
          validationResult.error = jsonError.message;
        }
        
        testResults.push({
          mode,
          success: true,
          responseTime: `${responseTime}ms`,
          settings: {
            verbosity: settings.verbosity,
            reasoningEffort: settings.reasoningEffort,
            schemaUsed: schema.name
          },
          tokens: {
            input: usage.input,
            output: usage.output,
            ...(usage.reasoning && { reasoning: usage.reasoning }),
            total: usage.input + usage.output + (usage.reasoning || 0)
          },
          validation: validationResult,
          responsePreview: jsonText.substring(0, 150) + (jsonText.length > 150 ? '...' : '')
        });
        
      } catch (error: any) {
        const responseTime = Date.now() - testStartTime;
        console.error(`🚨 Test failed for mode ${mode}:`, error.message);
        
        testResults.push({
          mode,
          success: false,
          error: error.message,
          responseTime: `${responseTime}ms`,
          settings: {
            verbosity: ModelSettings[mode]?.verbosity || 'low',
            reasoningEffort: ModelSettings[mode]?.reasoningEffort || 'medium',
            schemaUsed: AnalysisJsonSchemas[mode]?.name || 'unknown'
          }
        });
      }
    }
    
    const totalTime = Date.now() - overallStartTime;
    const successfulTests = testResults.filter(t => t.success).length;
    const totalTokens = testResults.reduce((sum, test) => 
      sum + (test.tokens?.total || 0), 0
    );
    
    return res.json({
      success: successfulTests === modes.length,
      message: `GPT-5-nano comprehensive test completed: ${successfulTests}/${modes.length} modes successful`,
      model: process.env.SONORA_MODEL || 'gpt-5-nano',
      testSummary: {
        totalTime: `${totalTime}ms`,
        averageTimePerMode: `${Math.round(totalTime / modes.length)}ms`,
        successRate: `${successfulTests}/${modes.length} (${Math.round(successfulTests / modes.length * 100)}%)`,
        totalTokensUsed: totalTokens,
        averageTokensPerMode: Math.round(totalTokens / modes.length)
      },
      tests: testResults,
      diagnostics: {
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'production',
        structuredOutputEnabled: true,
        reasoningCapabilityEnabled: true,
        supportedModes: modes,
        performance: testResults.map(t => ({
          mode: t.mode,
          responseTime: t.responseTime,
          reasoningEffort: t.settings?.reasoningEffort,
          tokensUsed: t.tokens?.total || 0,
          reasoningTokens: t.tokens?.reasoning || 0
        }))
      }
    });
    
  } catch (error: any) {
    console.error('🚨 GPT-5 test endpoint failed:', error.message);
    return res.status(500).json({
      success: false,
      message: `GPT-5-nano test endpoint failed: ${error.message}`,
      model: process.env.SONORA_MODEL || 'gpt-5-nano',
      error: error.message
    });
  }
});

// Simple moderation endpoint for client to check transcripts
const ModerateRequest = z.object({ text: z.string().min(1).max(20000) });
app.post('/moderate', async (req, res) => {
  try {
    const { text } = ModerateRequest.parse(req.body);
    const moderation = await createModeration(text);
    res.json(moderation);
  } catch (e: any) {
    if (e instanceof z.ZodError) {
      return res.status(400).json({ error: 'BadRequest', details: e.errors });
    }
    res.status(502).json({ error: 'ModerationFailed' });
  }
});


// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'NotFound' });
});

// Global error handler
app.use((error: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('Unhandled error:', error.message);
  if (!res.headersSent) {
    res.status(500).json({ error: 'Internal' });
  }
});

app.listen(PORT, () => {
  console.log(`Sonora API server listening on port ${PORT}`);
});
