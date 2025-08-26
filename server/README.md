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
  "model": "gpt-5-nano",
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
fly secrets set OPENAI_API_KEY=sk-... CORS_ORIGIN=https://sonora.app SONORA_MODEL=gpt-5-nano
fly deploy
```

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
