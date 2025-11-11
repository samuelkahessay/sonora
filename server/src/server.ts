import express from 'express';
import cors from 'cors';
import multer from 'multer';
import { z } from 'zod';
import fs from 'fs';
import { FormData, File } from 'undici';
import pinoHttp from 'pino-http';
import { RequestSchema, DistillDataSchema, LiteDistillDataSchema, EventsDataSchema, RemindersDataSchema, AnalysisJsonSchemas, DistillPersonalInsightDataSchema, DistillClosingNoteDataSchema } from './schema.js';
import { buildPrompt } from './prompts.js';
import { createChatCompletionsJSON, createModeration } from './openai.js';
import { chatCompletionsSupportsTemperature } from './caps.js';
import { sanitizeTranscript } from './sanitize.js';
import { correlationMiddleware } from './middleware/correlation.js';
import logger from './logging/logger.js';

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
    logger.warn({ error }, 'Could not create uploads directory');
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

// Correlation ID middleware (must be early in chain)
app.use(correlationMiddleware);

// HTTP request logging with pino
app.use(pinoHttp({
  logger,
  customLogLevel: (req, res, err) => {
    if (res.statusCode >= 500 || err) return 'error';
    if (res.statusCode >= 400) return 'warn';
    if (res.statusCode >= 300) return 'info';
    return 'debug';
  },
  customSuccessMessage: (req, res) => {
    return `${req.method} ${req.url} completed`;
  },
  customErrorMessage: (req, res, err) => {
    return `${req.method} ${req.url} failed: ${err.message}`;
  },
  customAttributeKeys: {
    req: 'request',
    res: 'response',
    err: 'error',
    responseTime: 'latency_ms',
  },
}));

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

    const wantsStream = (req.headers['accept'] || '').toLowerCase().includes('text/event-stream') || req.query.stream === '1';

    const basePayload: Record<string, any> = {
      model: 'meta-llama/llama-3.3-8b-instruct:free',
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user }
      ],
      temperature: 0.2,
      max_tokens: 32
    };

    const upstreamHeaders: Record<string, string> = {
      'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': process.env.SONORA_SITE_URL || 'https://sonora.app',
      'X-Title': process.env.SONORA_SITE_NAME || 'Sonora'
    };

    if (wantsStream) {
      res.status(200);
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');
      (res as any).flushHeaders?.();

      const sendEvent = (event: string, data: Record<string, unknown>) => {
        res.write(`event: ${event}\n`);
        res.write(`data: ${JSON.stringify(data)}\n\n`);
      };

      try {
        const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
          method: 'POST',
          headers: {
            ...upstreamHeaders,
            'Accept': 'text/event-stream'
          },
          body: JSON.stringify({
            ...basePayload,
            stream: true
          })
        });

        if (!response.ok || !response.body) {
          const text = await response.text().catch(() => '');
          logger.error({
            endpoint: '/title',
            mode: 'stream',
            status: response.status,
            statusText: response.statusText,
            responsePreview: text.slice(0, 200),
          }, 'OpenRouter /title stream error');
          sendEvent('error', { error: 'UpstreamFailed', status: response.status });
          res.end();
          return;
        }

        const decoder = new TextDecoder();
        let buffer = '';
        let aggregated = '';
        let finished = false;

        const processEvent = (rawEvent: string) => {
          if (!rawEvent.trim()) {
            return;
          }
          const lines = rawEvent.split('\n');
          const dataLines = lines
            .filter(line => line.startsWith('data:'))
            .map(line => line.slice(5).trim())
            .filter(Boolean);
          if (dataLines.length === 0) {
            return;
          }
          const payload = dataLines.join('');
          if (payload === '[DONE]') {
            const candidate = normalizeWhitespace(aggregated.replace(/\n/g, ' '));
            const validated = validateTitle(candidate, {
              maxChars: constraints.maxChars,
              language,
              isShortTranscript
            });
            if (validated) {
              sendEvent('final', { title: validated });
            } else {
              logger.warn({
                endpoint: '/title',
                mode: 'stream',
                candidate,
                constraints,
              }, 'Streaming title validation failed; using fallback');
              const fallback = validateTitle(buildFallbackTitle(sliced), {
                maxChars: constraints.maxChars,
                language,
                isShortTranscript: true
              }) || 'Voice Memo';
              sendEvent('final', { title: fallback, fallback: true });
            }
            res.end();
            finished = true;
            return;
          }
          try {
            const json = JSON.parse(payload);
            const delta = json?.choices?.[0]?.delta?.content ?? '';
            if (typeof delta === 'string' && delta.length > 0) {
              aggregated += delta;
              const partial = normalizeWhitespace(aggregated.replace(/\n/g, ' '));
              if (partial.length > 0) {
                sendEvent('interim', { title: partial.slice(0, constraints.maxChars * 2) });
              }
            }
          } catch (error) {
            logger.error({ error, endpoint: '/title', mode: 'stream' }, 'Failed to parse streaming chunk');
          }
        };

        for await (const chunk of response.body as any) {
          buffer += decoder.decode(chunk, { stream: true });
          let separatorIndex = buffer.indexOf('\n\n');
          while (separatorIndex !== -1) {
            const rawEvent = buffer.slice(0, separatorIndex);
            buffer = buffer.slice(separatorIndex + 2);
            processEvent(rawEvent);
            if (finished) {
              return;
            }
            separatorIndex = buffer.indexOf('\n\n');
          }
        }

        if (buffer.trim().length > 0) {
          processEvent(buffer);
        }

        if (!res.writableEnded && !finished) {
          res.end();
        }
        return;
      } catch (error) {
        logger.error({ error, endpoint: '/title', mode: 'stream' }, 'Streaming /title error');
        sendEvent('error', { error: 'Internal' });
        res.end();
        return;
      }
    }

    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: upstreamHeaders,
      body: JSON.stringify(basePayload)
    });

    if (!response.ok) {
      const text = await response.text().catch(() => '');
      logger.error({
        endpoint: '/title',
        status: response.status,
        statusText: response.statusText,
        responsePreview: text.slice(0, 200),
      }, 'OpenRouter /title error');
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

    logger.warn({
      endpoint: '/title',
      candidate,
      maxChars: constraints.maxChars,
      language,
      isShortTranscript,
    }, 'Title validation failed; using fallback');

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
    logger.error({ error: e, endpoint: '/title' }, 'Title generation error');
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
      logger.debug({ endpoint: '/transcribe', languageHint: langRaw }, 'Language hint provided');
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
        logger.warn({
          endpoint: '/transcribe',
          languageHint: langRaw,
          retry: true,
        }, 'Retrying transcription without language parameter (unsupported)');
        response = await callOpenAI(form2);
        data = await response.json();
      }

      if (!response.ok) {
        // Avoid logging upstream bodies; emit minimal error context
        const message = data?.error?.message || data?.message || 'transcription failed';
        logger.error({
          endpoint: '/transcribe',
          status: response.status,
          message,
        }, 'OpenAI transcription error');
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
      logger.info({
        endpoint: '/transcribe',
        detectedLanguage: detectedLang ?? 'und',
        avgLogprob: typeof avg_logprob === 'number' ? avg_logprob.toFixed(3) : undefined,
        confidence: typeof confidence === 'number' ? confidence.toFixed(3) : undefined,
        duration: typeof dur === 'number' ? dur.toFixed(2) : undefined,
        segmentCount: segCount,
      }, 'Transcription completed');
    } catch {}

    res.json({ 
      text: data.text ?? '',
      detected_language: detectedLang ?? undefined,
      avg_logprob,
      confidence,
      duration: typeof data.duration === 'number' ? data.duration : undefined
    });
  } catch (error: any) {
    logger.error({ error, endpoint: '/transcribe' }, 'Transcription error');
    res.status(500).json({ error: 'server error' });
  }
});

// Validate and wrap analysis response data based on mode
function validateAnalysisData(mode: string, parsedData: any): any {
  switch (mode) {
    case 'distill':
      return DistillDataSchema.parse(parsedData);
    case 'lite-distill':
      return LiteDistillDataSchema.parse(parsedData);
    case 'distill-summary':
      return { summary: parsedData.summary };
    case 'distill-actions':
      return { action_items: parsedData.action_items || [] };
    case 'distill-themes':
      return { key_themes: parsedData.key_themes || [] };
    case 'distill-personalInsight':
      return DistillPersonalInsightDataSchema.parse(parsedData);
    case 'distill-closingNote':
      return DistillClosingNoteDataSchema.parse(parsedData);
    case 'distill-reflection':
      return { reflection_questions: parsedData.reflection_questions || [] };
    case 'events':
      return EventsDataSchema.parse(parsedData);
    case 'reminders':
      return RemindersDataSchema.parse(parsedData);
    default:
      throw new Error(`Unknown mode: ${mode}`);
  }
}

// Main analyze endpoint
app.post('/analyze', async (req, res) => {
  const startTime = Date.now();

  try {
    // Validate request
    const { mode, transcript, historicalContext } = RequestSchema.parse(req.body);

    // Pro entitlement gating: all modes except lite-distill require Pro subscription
    const proModes = ['distill', 'distill-summary', 'distill-actions',
                      'distill-themes', 'distill-reflection', 'events', 'reminders'];

    if (proModes.includes(mode)) {
      const proHeader = req.headers['x-entitlement-pro'];
      if (proHeader !== '1') {
        return res.status(402).json({
          error: 'Pro subscription required',
          message: `${mode} requires a Pro subscription`
        });
      }
    }

    // Build prompts
    const { system, user } = buildPrompt(mode, transcript, historicalContext);

    if (!OPENAI_API_KEY) {
      return res.status(500).json({ error: 'Server missing OPENAI_API_KEY' });
    }

    // NON-STREAMING PATH: All modes use Chat Completions API with fallback chain
    // Try gpt-5-mini → gpt-5-nano → gpt-4o on error
    let jsonText: string;
    let usage: { input: number; output: number; reasoning?: number };
    let selectedModel = process.env.SONORA_MODEL || 'gpt-5-mini';

    try {
      // Try gpt-5-mini first (best quality + speed)
      const result = await createChatCompletionsJSON({
        system,
        user,
        model: selectedModel,
        mode
      });
      jsonText = result.jsonText;
      usage = result.usage;
    } catch (gpt5MiniError) {
      logger.warn({
        endpoint: '/analyze',
        mode,
        originalModel: selectedModel,
        fallbackModel: 'gpt-5-nano',
        error: (gpt5MiniError as any)?.message,
      }, 'Model fallback: gpt-5-mini failed, trying gpt-5-nano');

      // Fallback to gpt-5-nano
      try {
        selectedModel = 'gpt-5-nano';
        const result = await createChatCompletionsJSON({
          system,
          user,
          model: selectedModel,
          mode
        });
        jsonText = result.jsonText;
        usage = result.usage;
      } catch (gpt5NanoError) {
        logger.warn({
          endpoint: '/analyze',
          mode,
          originalModel: 'gpt-5-nano',
          fallbackModel: 'gpt-4o',
          error: (gpt5NanoError as any)?.message,
        }, 'Model fallback: gpt-5-nano failed, falling back to gpt-4o');

        // Final fallback to gpt-4o
        try {
          selectedModel = 'gpt-4o';
          const result = await createChatCompletionsJSON({
            system,
            user,
            model: selectedModel,
            mode
          });
          jsonText = result.jsonText;
          usage = result.usage;
        } catch (fallbackError) {
          logger.error({
            endpoint: '/analyze',
            mode,
            error: (fallbackError as any)?.message,
            modelsAttempted: ['gpt-5-mini', 'gpt-5-nano', 'gpt-4o'],
          }, 'All models failed');
          throw fallbackError;
        }
      }
    }
    
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
    
    // Validate response shape using shared validation function
    let validatedData;
    try {
      validatedData = validateAnalysisData(mode, parsedData);
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
        case 'distill':
          textForModeration = `${vd.summary}\n${(vd.action_items || []).map((a: any) => a.text).join(' \n')}\n${(vd.reflection_questions || []).join(' \n')}`;
          break;
        case 'lite-distill':
          textForModeration = `${vd.summary}\n${vd.personalInsight?.observation || ''}\n${(vd.simpleTodos || []).map((t: any) => t.text).join(' \n')}\n${vd.reflectionQuestion || ''}\n${vd.closingNote || ''}`;
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
        case 'distill-personalInsight':
          textForModeration = [
            vd.personalInsight?.observation || '',
            vd.personalInsight?.invitation || ''
          ].filter(Boolean).join(' \n');
          break;
        case 'distill-closingNote':
          textForModeration = vd.closingNote || '';
          break;
        case 'distill-reflection':
          textForModeration = (vd.reflection_questions || []).join(' \n');
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
      model: selectedModel,
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
    logger.error({
      error,
      endpoint: '/analyze',
      mode: req.body?.mode,
      latency_ms: latency,
    }, 'Server error in /analyze endpoint');
    res.status(500).json({
      error: 'Internal',
      message: error.message || 'Unknown error',
      latency_ms: latency
    });
  }
});

app.get('/keycheck', async (_req, res) => {
  try {
    if (!OPENAI_API_KEY) return res.status(500).json({ ok: false, message: 'OPENAI_API_KEY missing' });

    const startTime = Date.now();
    const { jsonText, usage } = await createChatCompletionsJSON({
      system: 'You are a GPT-5 validation service. Respond with valid JSON exactly as requested.',
      user: 'Respond with this JSON object: {"ok":true,"model":"gpt-5-mini","test":"keycheck"}',
      model: process.env.SONORA_MODEL || 'gpt-5-mini'
    });
    const responseTime = Date.now() - startTime;

    const parsed = JSON.parse(jsonText);
    const isValid = !!parsed?.ok;

    return res.json({
      ok: isValid,
      message: isValid ? 'GPT-5 key valid' : 'Invalid response from GPT-5',
      model: process.env.SONORA_MODEL || 'gpt-5-mini',
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
    logger.error({
      error: e,
      endpoint: '/keycheck',
      model: process.env.SONORA_MODEL || 'gpt-5-mini',
    }, 'Keycheck failed');
    return res.status(502).json({
      ok: false,
      message: `GPT-5-nano test failed: ${e?.message || 'Unknown error'}`,
      model: process.env.SONORA_MODEL || 'gpt-5-mini'
    });
  }
});

// Removed: /keycheck-stream streaming probe endpoint (analysis is non-streaming now)

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
    const modes = ['distill', 'lite-distill', 'distill-summary', 'distill-actions', 'distill-themes', 'distill-reflection', 'events', 'reminders'] as const;
    
    for (const mode of modes) {
      const testStartTime = Date.now();
      try {
        logger.info({ endpoint: '/test-gpt5', mode }, 'Testing GPT-5 mode');

        // Get prompt for this mode
        const { system, user } = buildPrompt(mode, testTranscript);

        const { jsonText, usage } = await createChatCompletionsJSON({
          system,
          user,
          model: process.env.SONORA_MODEL || 'gpt-5-mini',
          mode
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
            case 'lite-distill':
              validationResult.valid = !!(parsedData.summary && parsedData.keyThemes && parsedData.personalInsight && parsedData.reflectionQuestion && parsedData.closingNote);
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
          }
        } catch (jsonError: any) {
          validationResult.error = jsonError.message;
        }
        
        testResults.push({
          mode,
          success: true,
          responseTime: `${responseTime}ms`,
          settings: {
            schemaUsed: AnalysisJsonSchemas[mode]?.name || 'unknown'
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
        logger.error({
          endpoint: '/test-gpt5',
          mode,
          error: error.message,
          responseTime,
        }, 'Test failed for mode');

        testResults.push({
          mode,
          success: false,
          error: error.message,
          responseTime: `${responseTime}ms`,
          settings: {
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
      message: `GPT-5 comprehensive test completed: ${successfulTests}/${modes.length} modes successful`,
      model: process.env.SONORA_MODEL || 'gpt-5-mini',
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
          tokensUsed: t.tokens?.total || 0,
          reasoningTokens: t.tokens?.reasoning || 0
        }))
      }
    });
    
  } catch (error: any) {
    logger.error({
      error,
      endpoint: '/test-gpt5',
      model: process.env.SONORA_MODEL || 'gpt-5-mini',
    }, 'GPT-5 test endpoint failed');
    return res.status(500).json({
      success: false,
      message: `GPT-5 test endpoint failed: ${error.message}`,
      model: process.env.SONORA_MODEL || 'gpt-5-mini',
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
  logger.error({ error, url: req.url, method: req.method }, 'Unhandled error');
  if (!res.headersSent) {
    res.status(500).json({ error: 'Internal' });
  }
});

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    logger.info({ port: PORT, environment: process.env.NODE_ENV || 'development' }, 'Sonora API server started');
  });
}

export default app;
