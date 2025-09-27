Distill Lite / Pro – Product & Implementation Plan

Scope
- Align Distill to a wellness-first experience.
- Free (Lite): Auto Title, Summary, Reflection Questions.
- Pro: Everything in Lite + Action Items.
- Remove Key Themes from Distill to avoid overlap with Themes mode.

Pricing & Quotas
- Free: 60 minutes/month recording (DefaultRecordingQuotaPolicy).
- Pro: Unlimited recording. Themes, Todos, Content (Analysis) remain Pro benefits per Paywall copy.
- AI analysis limits (Free): No separate credit counter initially. Control cost by truncation, tiny model, short outputs. Optional server-side soft token budget later if needed.

User Experience (by tier)
- Lite
  - Auto Title: 3–5 words, Title Case, no punctuation/emojis, ≤32 chars. Language-aware. Fallback to date+time.
  - Summary: 1–2 paragraphs; kind, validating tone; avoid prescriptive language.
  - Reflection Questions: 2–3 gentle prompts prioritizing self-awareness and small next steps.
- Pro
  - Action Items: 3–5 verb-first nudges. No owners/dates. Wellness tone (“Take a 5-minute walk”, “Write two reflective sentences”).
  - Access to Themes, Todos, and Content modes from the Analysis area (unchanged gating).

Design Principles
- Wellness-aligned language (self-compassion, curiosity, small steps).
- Keep Distill concise; deeper analysis belongs in Themes/Todos/Content.
- Remove Key Themes from Distill; show Themes as its own mode when Pro.

Technical Plan
1) Distill UI
   - Hide Key Themes section in Distill.
   - Gate Action Items to Pro via StoreKit entitlement.
   - Keep Summary and Reflection for all users.
2) Auto Title (Phase 2)
   - Service: Tiny-model call with strict format rules; input slice = first 1–3 min + last ~1 min (or ~1.5–2k chars). Validation pipeline: dedupe, stopwords, token count, max length, generic phrase rejection → fallback.
   - UseCase: On transcription completion, if `Memo.customTitle` is empty, request title; save to memo and spotlight/share filenames (already derived from customTitle).
   - Flags: start disabled; enable after server endpoint is ready.
3) Free Cost Controls
   - Truncation and output caps for Free Distill Lite.
   - Tiny model only; early-stopping. Consider soft monthly token budget server-side if needed.
4) Pro Experience
   - Full transcript context and richer model allowed.
   - Action Items always visible for Pro; keep Themes/Todos/Content behind Pro.

Prompt Guidelines (server)
- Summary (Lite/Pro):
  - Goal: Calm, non-judgmental summary of what matters; ≤160 words.
  - Avoid: diagnostics, therapy claims, directives.
  - Do: validate feelings, spotlight patterns, suggest gentle attention areas.
- Reflection Questions (Lite/Pro):
  - 2–3 questions. One “awareness” (what am I noticing?), one “tiny next step”, optional “connection/values”.
  - No “should”; prefer “could”, “might”, “what would it feel like to…”.
- Action Items (Pro):
  - 3–5 small nudges; 1–2 sentences max; verb-first.
  - Avoid owners/dates/priorities; avoid workplace assignment framing.
- Auto Title (All):
  - 3–5 words, Title Case, no punctuation/emojis, ≤32 chars, language-aware.
  - Reject generic outputs (e.g., “Meeting”) unless paired with a specific noun.

Rollout
- Phase 1: Hide Key Themes in Distill; gate Action Items to Pro (done). Ship copy updates.
- Phase 2: Implement Title Suggestion service and use case; feature flag off by default.
- Phase 3: Enable Auto Title for a % of users; measure edit rate; tune prompts/validation.
- Phase 4: Adjust Free truncation if costs require; consider soft token budget.

Success Metrics
- Title: edit rate, fallback rate, language accuracy.
- Lite: latency, summary length distribution, reflection engagement.
- Pro: Action Items copy/usage rate; upgrade conversions.
- Cost: average tokens per Free Distill; per-user distribution.

Open Questions
- Where to surface “Upgrade for Action Items” affordance (banner/button) in Distill for Free? Initial iteration hides the section; consider subtle CTA.
- Auto Title source: server-run tiny model vs. client heuristic; begin server endpoint proposal.

Server Implementation Notes (Fly.io)
- Endpoint: POST /title
  - Request JSON: { transcript: string, language?: string, rules?: { words: "3-5", titleCase: true, noPunctuation: true, maxChars: 32 } }
  - Response JSON: { title: string }
- Model: OpenRouter meta-llama/llama-3.3-8b-instruct:free via OPENROUTER_API_KEY (.env)
- Example (Python):
  - See OpenRouter sample; set base_url=https://openrouter.ai/api/v1; model as above.
  - Prompt: “Return a 3–5 word title capturing the main topic. Title Case, no punctuation/emojis, ≤32 chars, output words only. Use transcript language. Transcript: <slice>.”
- Enforcement: server must validate length, word count, punctuation; reject generic terms.
- Cost control: slice input (~1.5–2k chars), early stopping.
- Deploy: set OPENROUTER_API_KEY on Fly.io; redeploy API. Auto-title runs automatically client-side after transcription.
