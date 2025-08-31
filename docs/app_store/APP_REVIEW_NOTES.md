App Review Notes – Sonora

Summary

- Sonora records short voice memos and (optionally) transcribes and analyzes them using our secure backend. The app supports background recording and provides a Live Activity for quick status and an action to stop recording.

Core Functionality

- Microphone access: Required to record voice memos.
- Background audio: Recording can continue when the app is backgrounded; the app declares UIBackgroundModes = audio and configures AVAudioSession appropriately.
- Live Activity: Shows recording status and a stop button. Frequent Live Activity updates are disabled.
- Networking: Audio files can be uploaded to our backend for transcription and analysis over HTTPS.

Server Endpoints

- Base: https://sonora.fly.dev
- Transcription: POST /transcribe (OpenAI Whisper)
- Analysis: POST /analyze (OpenAI GPT-4o-mini) — returns JSON with optional moderation metadata.
- Moderation: POST /moderate (OpenAI moderation) — used to check AI outputs (e.g., transcripts) client-side.

Privacy

- No tracking. No third-party SDKs.
- Audio recorded by the user may be uploaded to our backend for the explicit purpose of transcription and analysis initiated by the user. No personal identifiers are collected in-app.
- A Privacy Policy link is provided in App Store Connect (we can supply on request).

Review Instructions (Optional)

1) Launch the app and allow Microphone access when prompted.
2) Tap the record button to start recording. Lock the device; recording continues in the background.
3) Observe the Live Activity (and Dynamic Island on supported devices). Tap “Stop” or unlock the device and stop from the app.
4) Open a memo and choose “Transcribe” to upload and receive a transcription. Optionally “Analyze” to see summarized insights.

Notes

- The app does not require App Groups. The Live Activity is managed via ActivityKit APIs and does not share files or preferences with the host app.
- Network calls use standard HTTPS only; no ATS exceptions.
 - AI labeling and moderation: Transcription and analysis screens display an “AI-generated” label. If moderation flags content, a safety notice appears; the app does not present deceptive or harmful content without a warning.
