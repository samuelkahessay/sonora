# Sonora v1.1.0 Tasks - Thursday, September 18, 2025

- Context: some of these tasks are completed, some are in progress, some have not been started yet, 

- Liquid Glass
    - Updated Icon
    - Updated controls
    - Updated overall UI 

- [x]  Ensure prompts show up properly
- [x]  The memo list view should be minutes from the recording ended, not when the recording started
- [ ]  might have to work on use case where user goes to memo details when they’re recording
- [x]  Why does the transcription stay “Transcribing (auto) 12/81..” when transcribing via cloud
- [x]  When you hit the stop button after hitting record, it saves properly but it goes back to 00:00 (the timer on the recording view)
- [ ]  Local transcription does not work
- [ ]  Remove fillers and polish transcript in English
- [ ]  Add voice memo imports
- [ ]  Language setting

- We have to devise a freemium model
    - What are we putting behind a paywall

- [ ]  Calendar and events
- [ ]  Improved Distill Prompt
    - [ ]  Insights
    - [ ]  Synthesis
- [ ]  Liquid glass
- [ ]  In-App purchases
- [ ]  Better screenshots for app store marketing
- [ ]  Better on boarding
- [ ]  Transcription language selection

# Version 1.1

- The key is

# Features

- [ ]  Calendar and events
- [ ]  Improved Distill Prompt
    - [ ]  Insights
    - [ ]  Synthesis
- [ ]  Liquid glass
- [ ]  In-App purchases
- [ ]  Better screenshots for app store marketing
- [ ]  Better on boarding
- [ ]  Transcription language selection

### AI Analysis — Options (icon hints)

- Distill (droplet)
- Insights (magnifying glass) — also reference prior memos for broader context
- Highlights (highlighter) — notable quotes / emphatic statements
- Action Items (checkbox) — directives + blockers

### Onboarding / Personalization

- [ ]  Ask first name (no account required)
    - Copy ideas: “Welcome to Sonora — what should I call you?”
- [ ]  Use name in RecordingView prompt (e.g., “How was your day, Sam?”)
    - [ ]  Rotating prompt catalogue
    - [ ]  “Inspire me” button (topic suggestions)

## Marketing

- “Distill your thoughts while you walk”
- chaos → clarity
- Unique selling position:
    - Brand as the clarity layer for your mind. Voice is just the input modality.
    - Anchor the USP: “Record anything → get clarity you couldn’t see yourself.”

---

# P0

## Notifications

- Streak system
- Notification every day at a certain time, certain amount of times per week Y
- 

## Improved Prompts (both Cloud and Local Model)

- Improve the server-side prompts and local model prompts
- Integrate “Insights” into the comprehensive Distillation prompt
- What’s the difference between synthesis and summary?

## Auto-End Recording

- If no voice detected for 1 minute, end the recording, notify the reason to the user the reason for auto-ending the recording

## Settings

- Language selection for transcription (default: Auto) - only for cloud

## Monetization

- In-App Purchases
    - Free: Taste of clarity, perfect for casual users
        - 10 minute daily limit
        - 50 total minutes a month
    - Paid:  Full clarity ecosystem for serious self-reflection
        - Unlimited
        - All AI analysis types (Insights, Highlights, Action Items)
        - Multi-language transcription
        - Calendar integration

## App Store Integrations

**Screenshot 1:**

Recording in action with beautiful waveform

**Screenshot 2:**

AI analysis results showcasing all four types

**Screenshot 3:**

Calendar integration showing contextual prompts

**Screenshot 4:**

Insights view showing cross-memo patterns

**Screenshot 5:**

Action items extracted and organized

# P1

## Calendar Integration

- From the voice memo, during the distillation (AI analysis), detect events and reminders and then add them to the user’s calendar or reminders
- Have to determine the decision process between being added to the calendar or reminders (why calendar as opposed to reminder vice versa)

# P2

### **UI / Design Enhancements**

**Goal:** Increase polish + App Store appeal.

- **Feature:** Liquid glass background.
- **Feature:** Better screenshots for App Store.
    - Use simulator + staged copy.
    - Add captions: “Chaos → Clarity,” “Distill your thoughts while you walk.”
- **Tasks:**
    - Design pass for MemoList + Analysis screens.
    - Ensure legibility against glass background.
    - App Store screenshot pipeline (Figma → Xcode).

## Liquid Glass UI Design

### Visual Design System

**Description:** Implement modern, glass-morphism design language.

- **Elements:**
    - Translucent backgrounds with blur effects
    - Subtle gradients and depth
    - Smooth animations and transitions
    - Consistent visual hierarchy

### Micro-Interactions

- Recording pulse animation
- Analysis loading states
- Gesture-based navigation
- Haptic feedback integration

## Features (Prioritized)

### P0

- [ ]  Freemium gate: lock Cloud Whisper API + GPT-5 behind paywall

### P1

- [ ]  Settings
    - [ ]  Auto-transcribe
    - [ ]  Auto-analyze
    - [ ]  Transcription language selector
    - [ ]  Default share mode (just analysis / just memo / both)
- [ ]  Siri Shortcuts
- [ ]  Spotlight-searchable transcripts
- [ ]  Connect to calendar (create reminders)
- [ ]  Smart notifications (e.g., detect deadline → suggest calendar)
- [ ]  Basic monetization plumbing (RevenueCat link)
- [x]  “AI-generated” badge position (UI layout polish)

### P2

- [ ]  Dark mode
- [ ]  Folders
- [ ]  Tagging
- [ ]  Live waveform in recorder
- [ ]  Scrubber view for playback
- [ ]  Remove filler words
- [ ]  “CLEAN FILLER WORDS” button/setting
- [ ]  Strava integration
- [ ]  OneNote integration
- [ ]  Control Center quick action (start voice memo)
- [ ]  Ads to offset API costs (evaluate viability)
- [ ]  UML (developer docs)
- [ ]  Long mock audio/transcripts to validate paragraphing/formatting
- [ ]  Guided prompts (Apple Journal-style)
- [ ]  Better analysis buttons (Distill → Summary + Next Items)
- [ ]  Auto generated titles that are the summary of the transcript (3-6 words) — these are like journal entry titles

### AI Analysis — Options (icon hints)

- Distill (droplet)
- Insights (magnifying glass) — also reference prior memos for broader context
- Highlights (highlighter) — notable quotes / emphatic statements
- Action Items (checkbox) — directives + blockers

---

## Launch Plan — Tasks & Sub-tasks

1. **OperationCoordinator — Document & De-risk**
- [ ]  Map responsibilities (recording/background/transcription/analysis)
- [ ]  Comment states, transitions, race risks
- [ ]  Replace safe cases with `Task`/`TaskGroup` (no broad refactor)
- [ ]  Write ADR/README on current behavior + limits

### Phase 2 — Core Flow Lockdown (Days 8–14)

1. **Minimal Onboarding**
- [ ]  Welcome + value prop (privacy-first, local AI)
- [ ]  Mic permission with rationale
- [ ]  Choose default mode (Local vs Cloud) + freemium limits
- [ ]  Persist choices; add settings toggle
1. **Golden-Path E2E Testing**
- Recording
    - [ ]  Interruptions: call, alarm, background, lock
    - [ ]  Lifecycle transitions: start/stop across app states
- Transcription / Analysis
    - [ ]  Free-limit boundary behavior (last free minute)
    - [ ]  Offline→online queue resume + user feedback
    - [ ]  Actionable API error messages + retry paths
- CRUD (SwiftData)
    - [ ]  Edge titles/emojis/long strings
    - [ ]  Delete while playing → UI/data consistent
    - [ ]  Sort/search basics intact
- Sharing
    - [ ]  Memo filename in share sheet
    - [ ]  Include transcript toggle works
- [ ]  Log defects; fix blockers

### Phase 3 — Polish & Safeguards (Days 15–21)

1. **“Good Enough” UI Polish**
- [ ]  Fix layout/alignment on key screens
- [ ]  Add loading/empty/error states (Recording, List, Detail)
- [ ]  Haptics (start/stop, delete, confirmations)
- [ ]  Text pass (clarity, brevity)
1. **CI/CD Quality Gate**
- [ ]  Choose GitHub Actions or Xcode Cloud
- [ ]  Build + unit/UI tests on every PR/main
- [ ]  (Optional) SwiftLint fail on violations
- [ ]  Protect `main` on CI pass
- [ ]  README badge

### Phase 4 — Finalization & Ship (Days 22–27)

1. **App Store Prep**
- [ ]  Screenshots (all sizes)
- [ ]  Name, subtitle, keywords, description
- [ ]  Privacy policy URL + support URL
- [ ]  Fill `PrivacyInfo.xcprivacy` accurately
- [ ]  Device smoke test via TestFlight
1. **Submit for Review**
- [ ]  Promote final TF build
- [ ]  Complete ASC submission
- [ ]  Export compliance/content Qs
- [ ]  Submit; monitor; prep launch notes/press kit

---

## Bugs

- [ ]  Background recording choppy when app is backgrounded or switching tabs (investigate audio session/category, BG modes, Info.plist, buffering)

---

## Questions

- [ ]  Whisper model size selection (e.g., Large?) with WhisperKit
- [ ]  Using `gpt-5-mini` for cloud analysis?
- [ ]  Button set sufficiency (aim closer to “Athlete Intelligence”)

---

## Tools

- [ ]  Repo mix
- [ ]  21st.dev
- [ ]  https://www.claudelog.com/
- [ ]  https://apps.apple.com/ca/app/superwhisper/id6471464415
- [ ]  https://wisprflow.ai/
- [ ]  https://ui.shadcn.com/
- https://magicui.design/
- https://ads.apple.com/app-store/help/billing/0032-apple-ads-promo-credit
- https://traycer.ai/

---

## Finances

- Whisper API
- GPT-5-nano API
- [Fly.io](http://fly.io/)
- 2× ChatGPT Plus
- Claude Max

---

## Marketing

- “Distill your thoughts while you walk”
- chaos → clarity
- Unique selling position:
    - Brand as the clarity layer for your mind. Voice is just the input modality.
    - Anchor the USP: “Record anything → get clarity you couldn’t see yourself.”

---

- Test Driven Development