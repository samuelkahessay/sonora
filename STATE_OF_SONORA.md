# State of Sonora — Changes since 2025‑08‑29

This report summarizes notable changes made starting Aug 29, 2025, based on git history and diffs. It groups the work into features, fixes, architecture/infrastructure, and testing.

## Highlights
- Core Spotlight search integration with deep links to memos.
- Robust transcription pipeline: VAD + chunked transcription, language detection and confidence fallback, user language preference.
- Safety and integrity: Prompt‑injection defenses and output validation for analysis.
- New Settings experience: privacy export/delete with ZIP export, atomic delete‑all, AI disclosures, language settings.
- Onboarding flow with permission screens.
- Accessibility pass, Dynamic Type audit, semantic colors, and dark mode fixes.
- Feature‑oriented folder architecture and snapshot UI tests.

## Features Implemented
- Core Spotlight (SON‑41)
  - Added `Core/Spotlight/SpotlightIndexer` and `Core/Events/SpotlightEventHandler`.
  - Indexed memos with keywords and deep link `sonora://memo/<UUID>`.
  - Toggle via `AppConfiguration.searchIndexingEnabled`.

- Onboarding (SON‑40, SON‑29)
  - New onboarding screens, view model, and configuration.
  - Centralized permission prompts and initial setup.

- Settings and Data Management (SON‑33, 3cfd064, 162cfcb, f7b006f)
  - New Settings UI with sections for Privacy/Terms, Export, Delete‑All.
  - ZIP export service and toggles for including data.
  - Atomic delete‑all use case; ensured transcripts and analysis are removed with memos.

- Transcription Quality & Language (SON‑27 and follow‑ups)
  - VAD integration and chunked transcription (SON‑36 groundwork + VAD commits).
  - Client‑side language detection, quality evaluator, confidence fallback.
  - User‑selectable preferred transcription language in Settings.
  - Handling for empty audio, wrong language, and silence.

- Analysis Safety (SON‑61, SON‑71, SON‑39, SON‑28)
  - Guardrails for prompt injection and output validation.
  - Moderation service layer + UI badges/disclosures for AI features.

- Live Activity UX
  - LiveActivity service in DI; continued integration within recording flow.

## Bugs Fixed / Improvements
- Theming & Dark Mode
  - Fixed semantic colors and SwiftUI usage across views.
  - Completed dark mode audit.

- Accessibility (SON‑64)
  - Added labels/hints, improved focus order, haptics manager, and minor UI affordances.
  
- Dynamic Type (KAH‑32)
  - Audit across core views and components; improved scaling behavior.

- Data Operations
  - Atomic deletes and consistent cascade removal for transcripts/analysis.
  - Improved data export ZIP and reliability in Settings.

## Architecture & Infrastructure
- Feature Folder Architecture (62e0f7e)
  - Migrated views and view models into feature‑scoped directories.
  - Updated documentation to reflect structure.

- Concurrency & Progress (SON‑36)
  - OperationCoordinator and related types enhanced to support progress reporting and coordination.

- Dependency Injection
  - DI container expanded to register new services (moderation, live activity, spotlight indexer) and repositories/use cases.

- Configuration
  - Expanded `AppConfiguration` for search indexing toggle and language preferences.

## Testing
- Snapshot UI Tests (b2272af)
  - Added snapshot suites for primary screens and components.

- Spotlight Tests
  - Added unit tests for Spotlight index trigger behavior.

## Developer Docs
- App Store docs updated (privacy labels, submission checklist).
- Added QA guide for Spotlight.
- Architecture and README updated for new folder layout and theming system.

## Notable Files/Areas Touched
- Core Spotlight: `Core/Spotlight/SpotlightIndexer.swift`, `Core/Events/SpotlightEventHandler.swift`, `Core/Events/EventHandlerRegistry.swift`, `Core/Configuration/AppConfiguration.swift`
- Onboarding: `Features/Onboarding/*`, `Core/Configuration/OnboardingConfiguration.swift`
- Settings & Data: `Features/Settings/*`, `Data/Services/DataExportService.swift`, `Domain/UseCases/System/DeleteAllUserDataUseCase.swift`
- Transcription: `Data/Services/TranscriptionService.swift`, `Domain/UseCases/Transcription/*`, `Core/Configuration/WhisperLanguages.swift`
- Analysis & Safety: `Core/Security/AnalysisGuardrails.swift`, `Data/Services/AnalysisService.swift`, `Data/Repositories/AnalysisRepositoryImpl.swift`, `Models/*`
- Architecture & UI: `Core/UI/DesignSystem/*`, feature folders under `Features/*`, snapshot tests under `SonoraTests/Snapshot/*`

## Known Risks / Follow‑ups
- Spotlight: ensure indexing remains optional and performant; consider batch sizing and background scheduling.
- Language handling: continue tuning thresholds for detection and confidence fallback with real‑world audio.
- Moderation & guardrails: iterate rules and logging to minimize false positives while preserving safety.
- Snapshot tests: expand coverage for edge states (empty, failures, long content).

---
Generated from git history (since 2025‑08‑29) to aid release planning and QA.

## Commit Timeline (Oldest → Newest)
- 002f492 — Dark mode audit
  - Introduced semantic color system and theme environment scaffolding.

- 62e0f7e — Feature folder architecture
  - Migrated views/view models into `Features/*`; updated docs to reflect structure.

- b2272af — Add snapshot UITests
  - Added snapshot coverage for primary screens and components with baselines.

- 31192d2 — Fix theme/semantic colours in SwiftUI
  - Standardized semantic color usage across key views and VMs; README/ARCHITECTURE updates.

- bfa70e9 — KAH-32: Dynamic Type audit
  - Ensured fonts, sizes, and layouts adapt well to larger accessibility sizes.

- 4546903 — SON-33: Settings view with Privacy, Terms, and Export/Delete UI
  - Implemented Settings screens; added Privacy controller and design system tweaks.

- 7df6566 — Improve UI for SettingsView
  - Iterated interaction/visual polish for Settings.

- 3cfd064 — Improve ZIP data export and export setting toggles
  - Added `DataExportService`, export toggles, wiring into Settings; minor app init changes.

- f7b006f — Ensure transcripts and analysis are also deleted in delete-all
  - Cascade delete behavior from memos to transcripts/analysis.

- 162cfcb — Atomic deletes
  - Added `DeleteAllUserDataUseCase`; hardened Privacy controller for atomic operations.

- e2f9085 — SON-35: Document privacy labels in APP_STORE.md
  - Updated store documentation for privacy disclosures.

- d6d7780 — SON-36: Create progress infrastructure
  - Expanded `OperationCoordinator`, status/types to support progress and coordination.

- 90b885e/327074e — VAD groundwork
  - Better VAD; beginnings of confidence and language fallback; chunked transcription integration points.

- e1e5acb — Create language quality evaluator
  - Added evaluator to score transcription quality and compare alternatives.

- fea2de5 — Wire new language confidence and fallback into use case
  - Integrated evaluator and fallback decisioning in StartTranscription flow.

- 5d9c0f3 — Add transcription language in settings
  - Added user preference; plumbed into use case and UI (banner/section updates).

- 5b5e3c1 — SON-27: Empty/wrong-language/silence handling
  - Hardened StartTranscription and Settings for edge cases; Whisper languages config.

- 3aa6ba2 — SON-61: Prompt injection defense and output validation
  - Added Analysis guardrails; updated analysis use cases and server prompts.

- cd2c481 — SON-71, SON-39, SON-28
  - Moderation service/protocol, AI disclosures/badge, DI wiring, and server updates.

- 435752d — SON-59, SON-62
  - Introduced standardized error/loading/offline/empty UI components and VM hooks.

- 08330e7 — SON-40, SON-29: Onboarding permissions and screens
  - Onboarding flow, configuration, and integration with app init.

- f65ae89 — SON-64: Accessibility labels/hints, focus order
  - Focus manager, haptics, disclaimers; accessibility labels/hints across key views.

- e95f36d — SON-41: Core Spotlight indexing and deep links
  - Spotlight indexer + event handler; app wiring; unit tests; QA docs.

## Deep Dives (Vague Issue-Only Commits)

### 435752d — SON-59, SON-62
- New UI infrastructure for resilient states:
  - `Views/Components/ErrorAlertModifier.swift`: alert, banner, and loading-state modifiers; preview fixtures; `ErrorHandling` protocol for ViewModels.
  - `Views/Components/OfflineStateView.swift`: full-screen offline view, compact banner, and `networkStatus` overlay.
  - `Views/Components/ErrorStateView.swift` and `EmptyStateView.swift`: standardized error and empty placeholders.
- ViewModel updates (robustness and user feedback):
  - `Features/Memos/ViewModels/MemoDetailViewModel.swift` and `MemoListViewModel.swift`: added error properties, retry hooks, and handling paths.
  - `Features/Recording/ViewModels/RecordingViewModel.swift`: added state for errors/loading and likely integration with new modifiers.
- UI integration:
  - `Features/Memos/UI/MemosView.swift` and `MemoDetailView.swift`: wired new state views/modifiers, improved user feedback on failures/empties.
  - Minor polish in `Features/Analysis/UI/AnalysisResultsView.swift` to align with new theming/state components.

Impact: Introduces a consistent pattern for presenting errors/loading/offline across features; reduces duplicated UI/error handling logic; prepares for better testability of failure paths.

### cd2c481 — SON-71, SON-39, SON-28
- AI safety and disclosure:
  - `Core/Security`-adjacent UI: `Core/UI/AIBadge.swift` and `Features/Settings/UI/AIDisclosureSectionView.swift` to label AI-generated content and communicate limitations/safeguards.
- Moderation pipeline:
  - Protocol: `Domain/Protocols/ModerationServiceProtocol.swift` with `moderate(text:)` async API.
  - Implementation: `Data/Services/ModerationService.swift` (network POST to `/moderate`, 10s timeout) and `NoopModerationService.swift` (fallback stub).
  - Models: `Models/ModerationModels.swift` extended for decoding results.
  - DI: `Core/DI/DIContainer.swift` registers moderation service and threads it into use cases.
- Transcription use case integration:
  - `Domain/UseCases/Transcription/StartTranscriptionUseCase.swift` changes:
    - New dependencies: `moderationService`, VAD/chunking services, language evaluation/detection and `LanguageFallbackConfig` (threshold default 0.7).
    - Execution flow: after transcription, annotate AI metadata and call moderation; improved progress steps; robust conflict checks and error paths.
- UI usage:
  - `Features/Analysis/UI/AnalysisResultsView.swift`, `Features/Memos/UI/*`: reference `AIBadge` and disclosures; small adjustments to reflect moderated/AI content.
- Documentation:
  - Added `docs/app_store/APP_STORE_SUBMISSION.md` and `docs/app_store/SUBMISSION_CHECKLIST.md`; updated `APP_STORE.md` and `APP_REVIEW_NOTES.md`.
- Server alignment:
  - `server/src/openai.ts`, `server/src/schema.ts`, `server/src/server.ts` updated to support moderation and schema changes.

Impact: Establishes a moderation layer and clear user disclosure for AI features; integrates safety checks into transcription flow with configurable fallback behavior.
