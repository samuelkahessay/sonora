Distill Lite / Pro – Product & Implementation Plan

Scope
- Position Distill as THE hero feature—clarity from uninterrupted thinking.
- Free (Lite): Auto Title, Summary, Reflection Questions.
- Pro: Everything in Lite + Action Items + Key Themes.
- Focus: Show verbal processors what they actually meant after talking uninterrupted.

Pricing & Quotas
- Free: 60 minutes/month recording (DefaultRecordingQuotaPolicy).
- Pro: Unlimited recording. Themes, Todos, Content (Analysis) remain Pro benefits per Paywall copy.
- AI analysis limits (Free): No separate credit counter initially. Control cost by truncation, tiny model, short outputs. Optional server-side soft token budget later if needed.

User Experience (by tier)
- Lite
  - Auto Title: 3–5 words, Title Case, no punctuation/emojis, ≤32 chars. Language-aware. Fallback to date+time.
  - Summary: 1–2 paragraphs; reflective tone; shows "here's what you actually said"
  - Reflection Questions: 2–3 prompts to deepen thinking about patterns observed
- Pro
  - Action Items: 3–5 concrete next steps extracted from the thinking session
  - Key Themes: Recurring patterns across this recording
  - Access to Themes, Todos, and Content modes from the Analysis area (unchanged gating).

Design Principles
- Clarity-first: Help verbal processors see what they couldn't see while speaking
- Non-judgmental pattern observation (not therapy, just "you said X three times")
- Keep Distill concise; deeper analysis belongs in Themes/Todos/Content
- Emphasize Distill as THE core feature—this is why people use Sonora

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
  - Goal: Show "here's what you actually said" in distilled form; ≤160 words.
  - Avoid: therapy claims, emotional diagnoses, prescriptive advice.
  - Do: Neutral pattern observation ("You mentioned X three times"), surface key points.
- Reflection Questions (Lite/Pro):
  - 2–3 questions to deepen thinking about what they said.
  - Focus: "What pattern do you notice here?", "What would clarify this further?"
  - Avoid: therapeutic framing; this is thinking prompts, not emotional processing.
- Action Items (Pro):
  - 3–5 concrete next steps extracted from their thinking; verb-first.
  - Based on what THEY said they want to do, not what AI suggests.
  - Avoid: therapy homework, emotional regulation tasks.
- Auto Title (All):
  - 3–5 words, Title Case, no punctuation/emojis, ≤32 chars, language-aware.
  - Reject generic outputs (e.g., "Meeting") unless paired with a specific noun.

**CRITICAL DISCLAIMER**: All prompts must avoid clinical/therapeutic language. We're a thinking tool, not therapy.

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
