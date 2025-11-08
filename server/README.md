# Sonora API

Production-ready TypeScript API with transcription and analysis endpoints.

## Quickstart

```bash
cd server
npm install
cp .env.example .env
# Edit .env and set OPENAI_API_KEY
npm run dev
```

## API Endpoints

### POST /transcribe

Transcribes audio files using OpenAI Whisper.

**Request:** `multipart/form-data` with `file` field
**Response:**
```json
{
  "text": "transcribed text..."
}
```

### GET /keycheck

Tests GPT-5-mini API key validity and basic functionality.

**Response:**
```json
{
  "ok": true,
  "message": "GPT-5-mini key valid",
  "model": "gpt-5-mini",
  "performance": {
    "responseTime": "1240ms",
    "tokens": {
      "input": 25,
      "output": 12,
      "reasoning": 5
    }
  },
  "raw": { "ok": true, "model": "gpt-5-mini", "test": "keycheck" }
}
```

### GET /test-gpt5

Comprehensive test of all GPT-5-mini analysis modes with performance metrics.

**Response:**
```json
{
  "success": true,
  "message": "GPT-5-mini comprehensive test completed: 4/4 modes successful",
  "model": "gpt-5-mini",
  "testSummary": {
    "totalTime": "8340ms",
    "averageTimePerMode": "2085ms",
    "successRate": "4/4 (100%)",
    "totalTokensUsed": 1250,
    "averageTokensPerMode": 313
  },
  "tests": [
    {
      "mode": "distill",
      "success": true,
      "responseTime": "2340ms",
      "settings": {
        "verbosity": "medium",
        "reasoningEffort": "high",
        "schemaUsed": "distill_response"
      },
      "tokens": {
        "input": 245,
        "output": 156,
        "reasoning": 89,
        "total": 490
      },
      "validation": {
        "valid": true,
        "error": null,
        "keys": ["summary", "key_themes", "reflection_questions"]
      }
    }
  ],
  "diagnostics": {
    "timestamp": "2025-01-XX...",
    "structuredOutputEnabled": true,
    "reasoningCapabilityEnabled": true,
    "supportedModes": ["distill", "analysis", "themes", "todos"]
  }
}
```

### POST /analyze

Analyzes transcripts with different modes.

Supported modes:

- `tldr` – returns a concise summary and key points
- `analysis` – returns a summary and key points
- `themes` – groups related ideas and sentiment
- `todos` – extracts actionable items

**Request:**
```json
{
  "mode": "tldr" | "analysis" | "themes" | "todos",
  "transcript": "string (10-10k chars)"
}
```

**Response:**
```json
{
  "mode": "analysis",
  "data": { "summary": "...", "key_points": ["..."] },
  "model": "gpt-4o-mini",
  "tokens": { "input": 123, "output": 45 },
  "latency_ms": 850
}
```

## Test with curl

```bash
# TLDR mode
curl -s https://sonora.fly.dev/analyze \
  -H 'content-type: application/json' \
  -d '{"mode":"tldr","transcript":"I rambled about shipping the MVP next Friday and texting Sam to confirm the beta list."}'

# Analysis mode
curl -s https://sonora.fly.dev/analyze \
  -H 'content-type: application/json' \
  -d '{"mode":"analysis","transcript":"I rambled about shipping the MVP next Friday and texting Sam to confirm the beta list."}'

# Themes mode
curl -s https://sonora.fly.dev/analyze \
  -H 'content-type: application/json' \
  -d '{"mode":"themes","transcript":"The meeting was productive. We discussed the budget concerns and timeline issues. Everyone seemed optimistic about the launch."}'

# Todos mode
curl -s https://sonora.fly.dev/analyze \
  -H 'content-type: application/json' \
  -d '{"mode":"todos","transcript":"Remember to call mom tomorrow at 3pm and finish the report by Friday."}'
```

## Deploy to Fly.io

```bash
fly launch --name sonora --no-deploy
fly secrets set OPENAI_API_KEY=sk-... CORS_ORIGIN=https://sonora.app SONORA_MODEL=gpt-5-mini
fly deploy
```

### Analysis streaming

Analysis requests are non‑streaming. The server returns a single JSON response for `/analyze` with model, usage, latency, and validated data. Title generation may still use streaming, but the `/keycheck-stream` probe and analysis SSE have been removed.

## Response Schemas

**TLDR & Analysis modes:**
```json
{
  "summary": "2-4 sentence summary",
  "key_points": ["bullet 1", "bullet 2", "..."]
}
```

**Themes mode:**
```json
{
  "themes": [
    {"name": "Budget", "evidence": ["quote from transcript"]}
  ],
  "sentiment": "positive|neutral|mixed|negative"
}
```

**Todos mode:**
```json
{
  "todos": [
    {"text": "Call mom", "due": "2024-01-15T15:00:00Z"},
    {"text": "Finish report", "due": null}
  ]
}
```
