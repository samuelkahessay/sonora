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
- Recording: `BackgroundAudioService` (AV + background tasks) behind `AudioRepository` (impl: `AudioRepositoryImpl`)
- Transcription: `TranscriptionService` behind `TranscriptionRepository` (impl: `TranscriptionRepositoryImpl`) via `TranscriptionAPI`
- Analysis: `AnalysisService` behind `AnalysisRepository` (impl: `AnalysisRepositoryImpl`)
- Operation Coordination: `OperationCoordinator` + `OperationCoordinatorProtocol` (conflicts, status, progress)
- Event Bus: `EventBus` + handlers for decoupled reactions
- DI: `DIContainer` composes dependencies at the app edge

UI Implementation:
- **Native SwiftUI**: Standard Apple components with system styling
- **System Theming**: Automatic light/dark via `ThemeManager` and system colors
- **Recording Guardrails**: 60-second limit with 10s warning countdown; override via `SONORA_MAX_RECORDING_DURATION` in `AppConfiguration`

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
- Repositories isolate persistence and external dependencies (filesystem, AV, network) from domain logic:
  - `AudioRepositoryImpl` → Recording via `BackgroundAudioService`
  - `MemoRepositoryImpl` → Filesystem persistence and memo lifecycle
  - `TranscriptionRepositoryImpl`, `AnalysisRepositoryImpl`
- Services encapsulate system and transport logic: `BackgroundAudioService`, `TranscriptionService`, `AnalysisService`, `LiveActivityService`, `SystemNavigatorImpl`.

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

## Concurrency & Operations

- Long-running work (recording, transcription, analysis) is tracked by `OperationCoordinator` with conflict detection.
- Status surfaces via `OperationStatus` and ViewModels (e.g., `OperationStatusViewModel`).
- Use structured logging for traceability across flows.

## Events

- `EventBus` publishes `AppEvent` (e.g., `memoCreated`, `recordingStarted/Stopped`, `transcriptionCompleted`, `analysisCompleted`).
- Handlers (`LiveActivityEventHandler`, `MemoEventHandler`, `CalendarEventHandler`, `RemindersEventHandler`) react without coupling to feature code.
- `EventHandlerRegistry` wires handlers at startup.

## Current Status

- Clean Architecture adherence is high (targeting ~95%); Domain purity guarded and DI protocol-first across layers.
- Use Cases cover Recording, Transcription, Analysis, Memo, and Live Activity (19 use case files present).
- Presentation uses MVVM, consuming Combine publishers from repositories; NotificationCenter usage has been removed from VMs.
- Native SwiftUI with system theming; experimental “Liquid Glass” UI was removed in favor of native components.
- Recording guardrails: global 60s cap and 10s countdown via `BackgroundAudioService` surfaced through `AudioRepository`.
- Live Activities/Dynamic Island implemented with Start/Update/End use cases and a stop AppIntent.

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

- Core: `Sonora/Core/*` (DI, Events, Concurrency, Logging, Configuration)
- Domain: `Sonora/Domain/UseCases/*`, `Sonora/Domain/Protocols/*`, `Sonora/Domain/Models/*`
- Data: `Sonora/Data/Repositories/*`, `Sonora/Data/Services/*`
- Presentation: `Sonora/Presentation/ViewModels/*`, `Sonora/Views/*`
