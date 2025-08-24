// index.js
import express from "express";
import multer from "multer";
import cors from "cors";
import fetch from "node-fetch";
import fs from "fs";
import FormData from "form-data";
import "dotenv/config";

const app = express();
app.use(cors());
app.use(express.json());

// ensure uploads dir exists (multer doesn't create it)
fs.mkdirSync("uploads", { recursive: true });
const upload = multer({ dest: "uploads/" });

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
if (!OPENAI_API_KEY) {
  console.error("Missing OPENAI_API_KEY in environment");
  // Still serve /health so Fly doesn't loop-crash; just make /keycheck fail.
}

// Unconditional health check (used by Fly)
app.get("/health", (_req, res) => {
  res.status(200).json({ ok: true });
});

// Key validation endpoint (optional)
app.get("/keycheck", async (_req, res) => {
  try {
    const r = await fetch("https://api.openai.com/v1/models", {
      headers: { Authorization: `Bearer ${OPENAI_API_KEY}` }
    });
    if (!r.ok) {
      return res.status(500).json({
        ok: false,
        error: `OpenAI key invalid (status ${r.status})`
      });
    }
    res.json({ ok: true, message: "Key valid" });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

app.post("/transcribe", upload.single("file"), async (req, res) => {
  try {
    if (!OPENAI_API_KEY) return res.status(500).json({ error: "Server missing OPENAI_API_KEY" });
    if (!req.file) return res.status(400).json({ error: "file missing" });

    const form = new FormData();
    form.append("file", fs.createReadStream(req.file.path), req.file.originalname || "audio.m4a");
    form.append("model", "whisper-1");

    const r = await fetch("https://api.openai.com/v1/audio/transcriptions", {
      method: "POST",
      headers: { Authorization: `Bearer ${OPENAI_API_KEY}` },
      body: form
    });

    const data = await r.json();

    // cleanup temp file
    fs.unlink(req.file.path, () => {});

    if (!r.ok) {
      console.error("OpenAI error", data);
      return res.status(r.status).json({ error: data.error?.message || "transcription failed" });
    }

    res.json({ text: data.text ?? "" });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "server error" });
  }
});

// ---- LISTEN: keep the process alive and bind to 0.0.0.0:8080 ----
const PORT = Number(process.env.PORT) || 8080;
const HOST = "0.0.0.0";
const server = app.listen(PORT, HOST, () => {
  console.log(`HTTP server listening on http://${HOST}:${PORT}`);
});

// graceful shutdown (optional, nice to have)
process.on("SIGTERM", () => server.close(() => process.exit(0)));
process.on("SIGINT", () => server.close(() => process.exit(0)));
