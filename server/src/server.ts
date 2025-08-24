import express from 'express';
import cors from 'cors';
import multer from 'multer';
import { z } from 'zod';
import fs from 'fs';
import { FormData, File } from 'undici';
import { RequestSchema, AnalysisDataSchema, ThemesDataSchema, TodosDataSchema } from './schema.js';
import { buildPrompt } from './prompts.js';
import { createChatJSON } from './openai.js';

const app = express();
const PORT = process.env.PORT || 8080;
const CORS_ORIGIN = process.env.CORS_ORIGIN || 'https://sonora.app';
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

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

    const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: { 
        'Authorization': `Bearer ${OPENAI_API_KEY}`
      },
      body: form
    });

    const data = await response.json() as any;

    // Cleanup temp file
    fs.unlink(req.file.path, () => {});

    if (!response.ok) {
      console.error('OpenAI error', data);
      return res.status(response.status).json({ 
        error: data.error?.message || 'transcription failed' 
      });
    }

    res.json({ text: data.text ?? '' });
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
    
    // Call OpenAI
    const { jsonText, usage } = await createChatJSON({ system, user });
    
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
        case 'tldr':
        case 'analysis':
          validatedData = AnalysisDataSchema.parse(parsedData);
          break;
        case 'themes':
          validatedData = ThemesDataSchema.parse(parsedData);
          break;
        case 'todos':
          validatedData = TodosDataSchema.parse(parsedData);
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
    
    const latency = Date.now() - startTime;
    
    // Return canonical response
    res.json({
      mode,
      data: validatedData,
      model: process.env.SONORA_MODEL || 'gpt-5-nano',
      tokens: {
        input: usage.input,
        output: usage.output
      },
      latency_ms: latency
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
    // minimal roundtrip via your existing client
    const { jsonText } = await createChatJSON({
      system: 'You are a ping.',
      user: 'Respond with {"ok":true} only.'
    });
    const parsed = JSON.parse(jsonText);
    return res.json({ ok: !!parsed?.ok, message: 'Key valid', raw: parsed });
  } catch (e:any) {
    return res.status(502).json({ ok: false, message: e?.message || 'OpenAI call failed' });
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