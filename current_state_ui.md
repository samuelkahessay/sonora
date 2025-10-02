# Sonora UI: Current State Overview

This document inventories the user‑facing surfaces in the Sonora iOS app, summarizes their functionality, and briefly explains how they are implemented. It focuses on SwiftUI screens, modals/sheets, and major reusable UI building blocks.


## App Shell

- Screen: App Shell and Tab Navigation
- Path: `Sonora/Views/ContentView.swift`
- Functionality
  - Hosts the main application UI with a two‑tab `TabView`.
  - Presents onboarding as a full‑screen cover on first launch.
  - Tab 0: Recording; Tab 1: Memos list and navigation to memo detail.
  - Resets Memos navigation stack when re‑tapping the Memos tab.
- Implementation
  - SwiftUI `TabView` + `NavigationStack` per tab; dependencies are created through `DIContainer` (
    view models and coordinators are injected).
  - `OnboardingView` is shown via `fullScreenCover` based on `OnboardingConfiguration.shouldShowOnboarding`.
  - Responds to `scenePhase` changes to notify the title generation coordinator.


## Onboarding Flow

- Screen: Onboarding Flow (Paged)
- Paths: `Sonora/Features/Onboarding/UI/OnboardingView.swift`,
  `Sonora/Features/Onboarding/UI/Components/NameEntryView.swift`,
  `Sonora/Features/Onboarding/UI/Components/HowItWorksView.swift`,
  `Sonora/Features/Onboarding/UI/Components/FirstRecordingPromptView.swift`
- Functionality
  - Paged flow introducing the app and collecting the user’s first name.
  - Pages: Name Entry → How It Works → First Recording Prompt.
  - Continues automatically or on button taps; dismisses when completed.
- Implementation
  - `OnboardingView` controls a `TabView` (page style) bound to an onboarding view model.
  - `NameEntryView` validates and submits a first name with auto‑focus, haptics, and accessibility.
  - `HowItWorksView` shows a stepper with animated visuals and privacy messaging.
  - `FirstRecordingPromptView` personalizes the call‑to‑action and offers tips before starting the first recording.
  - Errors surface via `errorAlert` modifier; state stored in `OnboardingConfiguration`.


## Recording

- Screen: Recording
- Paths: `Sonora/Features/Recording/UI/RecordingView.swift`,
  `Sonora/Features/Recording/UI/SonicBloomRecordButton.swift`,
  `Sonora/Features/Recording/UI/RecordingControlsView.swift`,
  `Sonora/Features/Recording/UI/Components/{DynamicPromptCard,FallbackPromptCard,PromptPlaceholderCard}.swift`
- Functionality
  - Requests microphone permissions with inline explainer and system prompt.
  - Central “Sonic Bloom” record button (idle/recording/paused), with timer overlay and auto‑stop countdown.
  - Pause/Resume/Stop controls while recording.
  - “Inspire Me” prompt surfacing (dynamic prompt fetch, fallback, or placeholder while loading).
  - Shows paywall sheet if usage/quota indicates an upgrade is needed.
- Implementation
  - `RecordingView` orchestrates permission gating, recording session state, and prompt lifecycle using injected view models.
  - Animated, brand‑themed `SonicBloomRecordButton` uses `TimelineView` and value‑driven animations; accessible labels/hints.
  - `RecordingControlsView` provides pause/resume/stop with haptics.
  - Prompt section renders `DynamicPromptCard` when loaded, `PromptPlaceholderCard` during load, or `FallbackPromptCard` as a default.
  - Accessibility: focused elements shift between permission button, record button, and status text; reduce‑motion respected.


## Memos List

- Screen: Memos
- Path: `Sonora/Features/Memos/UI/MemosView.swift`
- Functionality
  - Displays memos grouped by contextual time periods (Today/Morning/Afternoon/Evening, Yesterday, This Week, etc.) or as a flat list based on sort.
  - Toolbar: settings, edit mode toggle, sort menu (Date, A–Z, Duration), and Filters.
  - Search bar; swipe actions; bulk selection with a bottom delete bar.
  - Navigates to `MemoDetailView` on tap.
  - Presents `SettingsView` as a sheet; `MemoFiltersSheet` for filtering options.
- Implementation
  - Uses a `MemoListViewModel` and caches grouped sections for performance.
  - List composition via custom row presentation (`MemoRowView`) and selection/drag accessibility helpers.
  - Deep‑link handling through `EventBus` (e.g., open a memo by ID).
  - Error and loading handled via view modifiers (`errorAlert`, `loadingState`).


## Memo Detail

- Screen: Memo Detail
- Path: `Sonora/Features/Memos/UI/MemoDetailView.swift`
- Functionality
  - Header with editable title (double‑tap to rename), dynamic inline navigation title on scroll.
  - Audio playback controls with scrubber, skip forward/back, and time displays.
  - Transcription section: start/retry/status + progressive progress indicators and error banners.
  - AI “Distill” analysis: CTA to generate or view cached results; results may stream progressively.
  - Analysis output: summary, reflection questions, action‑item detection (events/reminders) with add flows.
  - Language detection notice for non‑English content; delete memo action; Share Sheet (audio/transcript/analysis).
- Implementation
  - `MemoDetailViewModel` provides state for playback, transcription, and analysis.
  - Distill/analysis rendered via `AnalysisSectionView` → `DistillResultView`/`AnalysisResultsView`.
  - Accessibility focus shifts to newly available content (transcript/analysis) with announcements; haptics on completion.
  - Uses `NotificationBanner` for inline warnings, `errorAlert`/`loadingState` for async operations.


## Analysis Results (Inline on Memo Detail)

- Screen: Analysis Results (inline section)
- Paths: `Sonora/Features/Analysis/UI/AnalysisSectionView.swift`,
  `Sonora/Features/Analysis/UI/AnalysisResultsView.swift`,
  `Sonora/Features/Analysis/UI/DistillResultView.swift`,
  `Sonora/Features/Analysis/UI/Components/*`
- Functionality
  - For Distill: progressive results (summary, action items, reflection questions) with partial updates while processing.
  - For other modes (Analysis, Themes, Todos): static result cards and lists.
  - Action items host section allows reviewing, editing, and adding detected events/reminders; includes batch review dialog.
- Implementation
  - Distill mode can stream partial data and progress; shows skeletons until completion.
  - `ActionItemsHostSectionView` coordinates visible detections and EventKit permission explainer.
  - Uses domain DTOs and view models for conflict resolution and batch add flows.


## Settings

- Screen: Settings
- Path: `Sonora/Features/Settings/UI/SettingsView.swift`
- Sections & Functionality
  - Usage: monthly recording usage/progress; Pro users see unlimited status.
  - Subscription: upgrade CTA or manage/restore purchases for Pro users.
  - Personalization: update display name; toggle “Show Guided Prompts”.
  - Transcription Language: picker for cloud Whisper language preference.
  - Data Management: export data (memos/transcripts/analysis) and import audio files.
  - About & Support: app version/build, support link; diagnostics in debug builds.
  - Privacy & Legal: links to policy and terms.
  - Danger Zone: delete all user data.
- Implementation
  - Each section is a self‑contained SwiftUI view (`SettingsCard` pattern) with injected services via `DIContainer`.
  - Export presents `ExportDataSheet`; share uses `ActivityView`.
  - Import shows `AudioImportPicker`; successful imports rename from filename and call `HandleNewRecordingUseCase`.
  - Entitlement gating uses a StoreKit service; upgrade opens `PaywallView`.


## Secondary/Modal Screens

- Screen: Paywall
- Path: `Sonora/Features/Settings/UI/PaywallView.swift`
- Functionality
  - Monthly/Annual plan picker, subscribe, restore purchases; shows errors and loading overlay.
- Implementation
  - `PaywallViewModel` wraps a StoreKit service (abstracted); successful purchase dismisses the sheet.

- Screen: Share Memo Sheet
- Path: `Sonora/Features/Memos/UI/ShareMemoSheet.swift`
- Functionality
  - Toggle which content to include (audio, transcript, analysis) and prepare a share bundle.
- Implementation
  - Binds to `MemoDetailViewModel`; sets smart defaults; on completion triggers system share sheet.

- Screen: Filters Sheet
- Path: `Sonora/Features/Memos/UI/MemosView.swift` (embedded `MemoFiltersSheet`)
- Functionality
  - Filter by transcript presence; optionally select start/end date.
- Implementation
  - Simple `Form` presented as a sheet; updates `MemoListViewModel` filters.

- Screen: Export Data Sheet
- Path: `Sonora/Features/Settings/UI/DataManagementSectionView.swift` (embedded `ExportDataSheet`)
- Functionality
  - Choose data categories to export (memos, transcripts, analysis) and generate a ZIP for sharing.
- Implementation
  - Uses `PrivacyController` to build an export; presents `ActivityView` to share the resulting file.

- Screen: Batch Add Action Items
- Path: `Sonora/Features/Analysis/UI/BatchAddActionItemsSheet.swift`
- Functionality
  - Review detected events/reminders together, select a calendar/list, edit per‑item details, and add in bulk.
- Implementation
  - Validates selection and destination; calls back to parent handler to perform creation via use cases.

- Screen: Event Confirmation and Edit
- Path: `Sonora/Features/Analysis/UI/EventConfirmationView.swift`
- Functionality
  - Select detected events, choose a calendar, optionally edit, then add to Calendar.
- Implementation
  - Loads calendars/defaults via EventKit repository; permission requests via `EventKitPermissionService`.

- Screen: Reminder Confirmation and Edit
- Path: `Sonora/Features/Analysis/UI/ReminderConfirmationView.swift`
- Functionality
  - Select detected reminders, choose a list, optionally edit, then add to Reminders.
- Implementation
  - Loads reminder lists/default via EventKit repository; requests permissions as needed.


## Live Activity & Dynamic Island

- Surface: Recording Live Activity (Lock Screen, Notification, Dynamic Island)
- Path: `SonoraLiveActivity/SonoraLiveActivityLiveActivity.swift`
- Functionality
  - Shows recording state, elapsed or countdown time, animated voice‑centric waveform, and a Stop action.
  - Tapping opens the app; Stop uses an App Intent.
- Implementation
  - `ActivityConfiguration` with custom SwiftUI views (`PremiumLiveActivityView`, `DynamicIslandBottomContent`).
  - Voice waveform adapts to Always‑On Display and color scheme; animations reduced when appropriate.


## Reusable Components and Systemwide UI Patterns

- Notification Banners
  - Path: `Sonora/Views/Components/NotificationBanner.swift`
  - Types: info, warning, error, success, language.
  - Dismissible; optional primary action; compact/full variants.

- Error, Loading & Unified States
  - Paths: `Sonora/Views/Components/ErrorAlertModifier.swift`, `Sonora/Views/Components/UnifiedStateView.swift`
  - `errorAlert` shows native alert with retry/settings actions; `errorBanner` shows inline banner.
  - `loadingState` overlays a spinner; `UnifiedStateView` standardizes empty/error/offline/ loading states.

- Design System & Theming
  - The app relies on `Color.semantic` tokens and `SonoraDesignSystem` typography/spacing.
  - Animations and haptics are centralized (e.g., `HapticManager`, value‑driven animations, reduce‑motion checks).


## Navigation Summary

- Root navigation is a two‑tab layout (Record, Memos), with modal/sheet overlays for Onboarding, Settings, Paywall, Filters, Export, Share, and Event/Reminder flows.
- Memo detail hosts transcription and analysis surfaces inline, avoiding nested scroll views.


## Implementation Notes (Architectural)

- Dependency Injection
  - UI creates view models and services via `DIContainer` factory methods.
  - Separation across Clean Architecture layers: UI avoids direct domain/service logic where possible.

- Accessibility
  - Extensive VoiceOver labels, hints, and focus management for dynamic content.
  - Reduce‑motion paths respected for animations.

- Error & State Handling
  - Standard modifiers: `errorAlert`, `errorBanner`, `loadingState`.
  - Inline notices (e.g., language detection, warnings during analysis or transcription).

- Performance
  - Memo grouping cached; animations are value/time‑driven and disabled when not on‑screen.


## Inventory: Primary User‑Facing Screens

- App Shell and Tabs — `Sonora/Views/ContentView.swift`
- Onboarding (Name Entry, How It Works, First Recording) — `Sonora/Features/Onboarding/UI/*`
- Recording — `Sonora/Features/Recording/UI/RecordingView.swift`
- Memos — `Sonora/Features/Memos/UI/MemosView.swift`
- Memo Detail — `Sonora/Features/Memos/UI/MemoDetailView.swift`
- Settings — `Sonora/Features/Settings/UI/SettingsView.swift`

Secondary/Modal (visible surfaces users interact with)
- Paywall — `Sonora/Features/Settings/UI/PaywallView.swift`
- Share Memo — `Sonora/Features/Memos/UI/ShareMemoSheet.swift`
- Filters — `Sonora/Features/Memos/UI/MemosView.swift` (embedded `MemoFiltersSheet`)
- Export Data — `Sonora/Features/Settings/UI/DataManagementSectionView.swift` (embedded `ExportDataSheet`)
- Batch Add Action Items — `Sonora/Features/Analysis/UI/BatchAddActionItemsSheet.swift`
- Event Confirmation & Edit — `Sonora/Features/Analysis/UI/EventConfirmationView.swift`
- Reminder Confirmation & Edit — `Sonora/Features/Analysis/UI/ReminderConfirmationView.swift`
- Live Activity / Dynamic Island — `SonoraLiveActivity/SonoraLiveActivityLiveActivity.swift`


---

This summary is intended to help an LLM analyze Sonora’s UI/UX: evaluate clarity of flows, discoverability, accessibility, motion & feedback, and the cohesion of the visual system (colors/typography/components) across screens.

