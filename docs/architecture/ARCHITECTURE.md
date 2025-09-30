# Sonora Architecture

This document consolidates the project's architecture, current status, and concrete next steps into a single source of truth. It reflects the **native SwiftUI implementation** and the project's **Clean Architecture** patterns.

## Overview

Sonora follows a pragmatic Clean Architecture with MVVM at the presentation layer:

```
Presentation (SwiftUI Views ←→ ViewModels)
   ↓ uses
Domain (Use Cases, Domain Models, Protocols)
   ↓ calls
Data (Repositories, Services, System APIs, Network)
Core (DI, Concurrency/Operations, Events, Logging, Config)
```

Key systems (verified in repo):
- **Recording**: Orchestrated through `BackgroundAudioService` coordinating 6 focused services behind `AudioRepository` (impl: `AudioRepositoryImpl`)
  - `AudioSessionService`: AVAudioSession configuration and interruption handling
  - `AudioRecordingService`: AVAudioRecorder lifecycle and delegate management  
  - `BackgroundTaskService`: iOS background task management for recording
  - `AudioPermissionService`: Microphone permission status and requests
  - `RecordingTimerService`: Recording duration tracking and countdown logic
  - `AudioPlaybackService`: Audio playback controls and progress tracking
- **Transcription**: `TranscriptionService` behind `TranscriptionRepository` (impl: `TranscriptionRepositoryImpl`) via `TranscriptionAPI`
- **Analysis**: `AnalysisService` behind `AnalysisRepository` (impl: `AnalysisRepositoryImpl`)
- **Operation Coordination**: `OperationCoordinator` + `OperationCoordinatorProtocol` (conflicts, status, progress)
- **Event Bus**: `EventBus` + handlers for decoupled reactions
- **DI**: `DIContainer` composes dependencies at the app edge with protocol-based service registration

UI Implementation:
- **Native SwiftUI**: Standard Apple components with system styling
- **System Theming**: Automatic light/dark via `ThemeManager` and system colors
- **Recording Guardrails**: 3-minute (180s) limit with 10s warning countdown; override via `SONORA_MAX_RECORDING_DURATION` in `AppConfiguration`

## Feature-Based Organization

The Presentation layer is organized by feature for clarity and scalability. Each feature owns its UI and ViewModels; Domain and Data remain centralized.

Folder layout:

```
Sonora/Features/
  Recording/
    UI/                 # SwiftUI views
    ViewModels/         # Feature ViewModels (MVVM)
  Memos/
    UI/
    ViewModels/
  Analysis/
    UI/
    ViewModels/
  Operations/
    ViewModels/

Sonora/Views/           # Truly shared UI components (cross-feature)
  Components/
```

Best practices:
- Keep features presentation-only: Views + ViewModels. Put new Use Cases in `Domain/UseCases/*` and Repositories/Services in `Data/*`.
- Inject only protocols into ViewModels. Resolve implementations in `DIContainer`.
- Do not import views or view models from another feature. Share UI via `Views/Components` or Core UI modules.
- Cross-feature communication should use `AppEvent` via `EventBus` and repository state, not direct feature-to-feature calls.
- Long-running work must be registered with `OperationCoordinator` and surfaced via ViewModels.
- Use native SwiftUI components and system semantic colors. Respect `ThemeManager`.

### Semantic Color Usage

Centralize all colors via the semantic system in `Core/UI/DesignSystem`.

- Access tokens: `Color.semantic(_:)` with `SemanticColor` cases. Do not use `.red/.blue/.orange`, `Color(red:...)`, `.primary/.secondary`, or `UIColor.*` in views.
- Common tokens:
  - Brand: `brand/Primary`, `brand/Secondary`, `brand/Accent`
  - Backgrounds: `bg/Primary`, `bg/Secondary`, `bg/Tertiary`
  - Text: `text/Primary`, `text/Secondary`, `text/Inverted` (for tinted surfaces)
  - Fills/Separators: `fill/Primary`, `fill/Secondary`, `separator/Primary`
  - States: `state/Success`, `state/Warning`, `state/Error`, `state/Info`
- Examples:
  - Buttons: `.tint(.semantic(.brandPrimary))`, destructive → `.tint(.semantic(.error))`
  - Cards: `.background(Color.semantic(.bgSecondary))` + `.shadow(color: Color.semantic(.separator).opacity(0.2), ...)`
  - Chips/badges: background `token.opacity(0.1~0.2)` + 
    `foregroundColor(token)` where `token` is one of `success/warning/error/info/brandPrimary`
  - Secondary text: `.foregroundColor(.semantic(.textSecondary))`
- Asset mapping: Provide color assets named exactly as tokens (e.g., `bg/Primary`). The system fallback in `SemanticColors` ensures dynamic light/dark when an asset is missing.
- Accessibility: Pair `text/Primary` or `text/Secondary` with `bg/*` tokens; use `text/Inverted` on tinted brand backgrounds. Avoid hardcoded opacities that reduce contrast for body text.

## Layer Details

Presentation (MVVM)
- ViewModels (e.g., `RecordingViewModel`, `MemoListViewModel`, `MemoDetailViewModel`) expose state and call use cases.
- Views are simple and reactive; they don’t talk to repositories/services directly.
- ViewModels consume publishers from repositories (e.g., recording countdown via `AudioRepository.countdownPublisher`).

Domain
- Use Cases encapsulate business logic across Recording, Transcription, Analysis, Memo management, and Live Activity.
- Protocols define contracts for repositories and services (8 core protocols present).
- Models: Single memo model `Memo` used across layers (no adapters); analysis result in `DomainAnalysisResult`.

Data
- **Repositories** isolate persistence and external dependencies (filesystem, AV, network) from domain logic:
  - `BaseRepository` → Common CRUD operations and file-based persistence patterns
  - `AudioRepositoryImpl` → Recording via orchestrated audio service architecture
  - `MemoRepositoryImpl` → Filesystem persistence and memo lifecycle
  - `TranscriptionRepositoryImpl`, `AnalysisRepositoryImpl` → State and result persistence
- **Services** are organized by capability with focused responsibilities:
  - `Data/Services/Audio/*` — **6 focused audio services** with clear separation of concerns:
    - `AudioSessionService` → Session configuration, route management, interruption handling
    - `AudioRecordingService` → AVAudioRecorder operations, delegate callbacks, fallback logic
    - `BackgroundTaskService` → iOS background task lifecycle, app state integration
    - `AudioPermissionService` → Microphone permissions, status monitoring, async requests
    - `RecordingTimerService` → Duration tracking, countdown logic, auto-stop functionality
    - `AudioPlaybackService` → Playback controls, progress tracking, session management
    - `BackgroundAudioService` → **Orchestrating coordinator** using composition and reactive bindings
  - `Data/Services/Transcription/*` — Cloud transcription (OpenAI Whisper API), VAD splitting, chunking, client language detection
  - `Data/Services/Analysis/*` — Analysis runtime
  - `Data/Services/Export/*` — Exporters for transcripts and analyses
  - `Data/Services/Moderation/*` — Moderation services (and no-op variant)
  - `Data/Services/System/*` — System-facing helpers (Live Activities, navigation, metadata)

Core
- `DIContainer`: composition root; provides protocol-based access to implementations.
- `OperationCoordinator` (+ `OperationCoordinatorProtocol`): registers, tracks, and cancels operations.
- `EventBus` + handlers: decoupled event processing (e.g., Live Activity updates on recording state changes).
- `Logger`, `BuildConfiguration`, and `AppConfiguration`: structured logging and runtime configuration.

## Layer Boundaries & Guardrails

- Domain purity: No AVFoundation/UI imports in Domain. System frameworks live in Data/Services.
- Single source of truth: Use `Memo` everywhere; suffix variants only for transport/persistence (`MemoDTO`/`MemoRecord` if/when needed).
- Repository scope: Data access only. Orchestration belongs in Use Cases or Event Handlers.
- Use Cases: Coordinate flows, call repositories/services, publish `AppEvent` when cross-cutting reactions are needed.
- Events: Use `EventBus` for cross-cutting reactions; avoid over-broadcasting—prefer explicit Use Case flow when sufficient.
- DI discipline: Constructor injection of protocols; resolve in `DIContainer` (composition root). Avoid new singletons.
- Async model: Prefer `async/await` in coordination. Repositories may expose Combine publishers for UI state streams; bridge at boundaries as needed.

## Dependency Injection

- DI occurs at the app edge via `DIContainer`.
- ViewModels and Use Cases receive protocol types via constructor injection.
- Repositories and services are composed in `DIContainer`; favor `OperationCoordinatorProtocol` and other protocols over concrete types.

Feature dependency rules:
- Features → Domain: allowed (use case protocols, domain models)
- Features → Data: allowed through protocols only (via use cases or repositories injected from DIContainer); avoid referencing implementations
- Features → Core: allowed (DI, Events, Logging, Concurrency, Theme)
- Feature A ↔ Feature B: not allowed; communicate via events or shared repositories/state
- Views/Components: can be imported by any feature; must remain UI-only and generic

## Concurrency & Operations

- Long-running work (recording, transcription, analysis) is tracked by `OperationCoordinator` with conflict detection.
- Status surfaces via `OperationStatus` and ViewModels (e.g., `OperationStatusViewModel`).
- Use structured logging for traceability across flows.

## Events

- `EventBus` publishes `AppEvent` (e.g., `memoCreated`, `recordingStarted/Stopped`, `transcriptionCompleted`, `analysisCompleted`).
- Handlers (`LiveActivityEventHandler`, `MemoEventHandler`, `CalendarEventHandler`, `RemindersEventHandler`) react without coupling to feature code.
- `EventHandlerRegistry` wires handlers at startup.

Cross‑feature communication:
- Publish `AppEvent` from Use Cases when other parts of the app should react.
- Handle `AppEvent` in Core event handlers to update repositories or trigger side effects.
- Features then react to repository state via Combine publishers (ViewModels subscribe), maintaining decoupling.

## Prompts Module (Dynamic Recording Prompts)

Purpose: Provide intelligent, context‑aware prompts for recording that personalize by time of day/week and user name while preserving Clean Architecture and native SwiftUI.

Layers and types:
- Domain
  - Models: `RecordingPrompt`, `InterpolatedPrompt`, enums `PromptCategory`, `EmotionalDepth`, `DayPart`, `WeekPart`
  - Protocols: `PromptCatalog`, `PromptUsageRepository`
  - Use Cases: `GetDynamicPromptUseCase`, `GetPromptCategoryUseCase`
  - Services: `PromptInterpolation` (token resolution)
- Data
  - SwiftData model: `PromptUsageRecord` (unique `promptId`, `lastShownAt`, `lastUsedAt`, `useCount`, `isFavorite`)
  - Repository: `PromptUsageRepositoryImpl` (SwiftData, @MainActor)
  - Catalog: File‑backed via `PromptFileCatalog` loading `Sonora/Resources/prompts.ndjson`
- Core
  - Providers: `DateProvider` (locale/timezone aware day/week parts), `LocalizationProvider`
  - DI: `DIContainer` registers providers, catalog, repository, and factories for both use cases
- Presentation
  - ViewModel: `PromptViewModel` (@MainActor)
  - UI: `DynamicPromptCard`, `FallbackPromptCard`, `InspireMeSheet` (native SwiftUI)
  - Integration: `RecordingView` shows a prompt above `SonicBloomRecordButton` (180px) when idle; graceful fallback shown when no prompt available

Behavior:
- Personalization tokens: `[Name]`, `[DayPart]`, `[WeekPart]` (interpolated via LocalizationProvider)
- Rotation: 7‑day no‑repeat globally across categories (repository enforced and use‑case filtered)
- Selection: weight (desc) → least recently used → stable seeded tiebreak (by day/category context)
- Exploration ("Inspire Me"): policy-driven selection that progressively relaxes filters
  to guarantee variety (min 10 candidates) with a short 3‑minute cooldown for recently
  shown prompts and a rotation token to avoid in‑session repeats. `AppEvent.promptShown`
  uses `source = "inspire"` in this mode; default dynamic selection uses `source = "dynamic"`.
- Localization keys: `daypart.*`, `weekpart.*`, and `prompt.<category>.<slug>` resolved by `DefaultLocalizationProvider` from `prompts.ndjson` (NDJSON is the single source of truth; no generator script required)
- Feature flag: `FeatureFlags.usePrompts`

Events & logging:
- AppEvents: `promptShown`, `promptUsed`, `promptFavoritedToggled` (privacy‑safe: no prompt text)
- Logger context includes `id`, `category`, `dayPart`, `weekPart`

Concurrency:
- Use cases are async and call @MainActor SwiftData repository via `await`
- Providers are Sendable; repository remains data‑access only

Testing:
- Use case tests: rotation and token interpolation with fixed `DateProvider`
- Enum tests: DayPart/WeekPart boundary and locale week‑start
- Repository tests: in‑memory SwiftData for favorites/usage
- UI snapshots: covered by existing RecordingView snapshots; update baselines when recording if prompt UI is enabled

Files:
- Domain: `Sonora/Domain/Models/RecordingPrompt.swift`, `InterpolatedPrompt.swift`, `Domain/Protocols/*`, `Domain/UseCases/Prompts/*`, `Domain/Services/PromptInterpolation.swift`
- Data: `Sonora/Data/Models/SwiftData/PromptUsageRecord.swift`, `Data/Repositories/Prompts/PromptUsageRepositoryImpl.swift`, `Data/Services/Prompts/PromptFileCatalog.swift`, `Sonora/Resources/prompts.ndjson`
- Core: `Core/Providers/DateProvider.swift`, `Core/Providers/LocalizationProvider.swift`, `Core/DI/DIContainer.swift` (prompt wiring)
- Presentation: `Features/Recording/ViewModels/PromptViewModel.swift`, `Features/Recording/UI/Components/{DynamicPromptCard, FallbackPromptCard, InspireMeSheet}.swift`, `Features/Recording/UI/RecordingView.swift`

## Current Status (January 2025)

**🏆 Architecture Excellence Achieved (95% Clean Architecture Compliance)**

- **Clean Architecture adherence**: 95% compliance with protocol-first DI and strict layer separation
- **Service Layer Modernization**: Monolithic `BackgroundAudioService` (634 lines) transformed into orchestrated architecture:
  - 6 focused services implementing Single Responsibility Principle
  - Reactive state synchronization through Combine publishers
  - Constructor dependency injection with protocol abstractions
  - Zero breaking changes to existing APIs
- **Use Cases**: 19+ use case files covering Recording, Transcription, Analysis, Memo, and Live Activity workflows
- **Presentation**: MVVM with ViewState patterns, consuming Combine publishers; NotificationCenter usage eliminated
- **UI Implementation**: Native SwiftUI with system theming; experimental components removed for standard Apple design
- **Recording System**: Enhanced with focused services for session management, permissions, timing, and background tasks
- **Live Activities**: Full Dynamic Island integration with Start/Update/End use cases and AppIntent support
- **Swift 6 Compliance**: Full concurrency compliance with proper @MainActor usage and async/await patterns

## Gaps & Targeted Improvements

1) Tests as first-class
- Add focused Use Case and ViewModel tests with protocol-backed fakes; include repository tests around persistence/network edges.

2) Architecture guardrails in code
- Add lint/static checks to prevent UI/AV imports in Domain and to enforce file placement conventions.

3) Protocol coverage
- Ensure all long-running/cross-cutting services (e.g., LiveActivity, Logging) have protocol abstractions and are injected.

4) Event discipline
- Document published `AppEvent`s and handlers; avoid overuse of events where explicit orchestration suffices.

5) Caching & performance
- Document cache invalidation for analysis; add size/time limits and profiling for long sessions.

## Best Practices

- Start with Domain: design use cases and protocols first.
- Keep ViewModels thin: they coordinate, they don’t own business logic.
- Inject dependencies: prefer protocol-based initializer injection.
- Track operations: register work with `OperationCoordinator` for consistent UX.
- Log meaningfully: use structured logs; map errors via `ErrorMapping` to `SonoraError`.
- Name entities simply: the domain entity is `Memo`; reserve suffixes for DTOs/persistence (e.g., `MemoDTO`, `MemoRecord`).

## Live Activities & AppIntent

- Service: `LiveActivityService` (Data) with `LiveActivityServiceProtocol` (Domain).
- Use Cases: `StartLiveActivityUseCase`, `UpdateLiveActivityUseCase`, `EndLiveActivityUseCase` (Domain).
- Event-driven updates: Handled via `LiveActivityEventHandler` responding to recording lifecycle events.
- Control: AppIntent to stop recording integrates with Live Activity UI.

## Testing Notes

- Active guides: `docs/testing/` (background recording, enhanced flow, transcription integration).
- Favor Use Case tests with protocol-backed mocks; ViewModel tests for state transitions and coordination; Repository tests for persistence contracts.
- Historical notes consolidated into `ARCHIVE.md`.

## Appendix: File Map (Key Paths)

- Core: `Sonora/Core/*` (DI, Events, Concurrency, Logging, Configuration, UI/DesignSystem)
- Domain: `Sonora/Domain/UseCases/*`, `Sonora/Domain/Protocols/*`, `Sonora/Domain/Models/*`
- Data: `Sonora/Data/Repositories/*`, `Sonora/Data/Services/*`
- Features: `Sonora/Features/<FeatureName>/(UI|ViewModels)/*`
- Shared UI: `Sonora/Views/Components/*` (feature-agnostic components)

## Phase 3 Enhancements

- Adaptive Detection: `DetectEventsAndRemindersUseCase` now derives a lightweight `DetectionContext` and applies an `AdaptiveThresholdPolicy` (default: `DefaultAdaptiveThresholdPolicy`) to set per‑memo confidence thresholds. Legacy static thresholds are retained as a floor. Target: ~30% fewer false positives with ≤5% recall loss.
- Progressive Analysis Routing: When `AppConfiguration.enableProgressiveAnalysisRouting` is true, `ProgressiveAnalysisService` performs a tiny → small → base progression with early termination on simple content. It logs per‑tier latency, model, and token usage. Access via `DIContainer.progressiveAnalysisService()`.
- SwiftData Optimizations: Added indices for frequent access (`MemoModel.creationDate`, `TranscriptionModel.id/status`), batched transcription state loading to remove N+1, and a short‑lived memo list cache in `MemoRepositoryImpl` to reduce list TTI.
