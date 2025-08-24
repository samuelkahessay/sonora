# Sonora Transcription Server

## Setup
1. `cd server && npm install`
2. Copy `.env.example` to `.env` and set `OPENAI_API_KEY`.
3. `npm run dev` (defaults to http://localhost:8787)

### Endpoints
- `POST /transcribe`  multipart/form-data field `file`
  - returns `{ "text": "..." }`
- `GET /health` sanity check with OpenAI key validation