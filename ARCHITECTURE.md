# Sonora Architecture

This document consolidates the project’s architecture, current status, and concrete next steps into a single source of truth. It reflects the lean, native SwiftUI UI and the recording defaults currently in place.

## Overview

Sonora follows a pragmatic Clean Architecture with MVVM at the presentation layer:

```
Presentation (SwiftUI Views ←→ ViewModels)
   ↓ use cases
Domain (Use Cases, Domain Models, Protocols)
   ↓ repositories/services
Data (Repositories, Services, System APIs, Network)
Core (DI, Concurrency/Operations, Events, Logging, Config)
```

Key systems:
- Recording: `BackgroundAudioService` (AV + background tasks) via `AudioRepositoryImpl` and `AudioRepository` protocol
- Transcription: `TranscriptionService` (conforms to `TranscriptionAPI`) + `TranscriptionRepository`
- Analysis: `AnalysisService` + `AnalysisRepository`
- Operation Coordination: `OperationCoordinator` with conflict control, queueing, and metrics
- Event Bus: App-wide event publication/subscription for decoupled features
- DI: `DIContainer` composes dependencies at the app edge

UI defaults:
- Native SwiftUI styling
- Global recording limit: 60 seconds, 10-second countdown
- Override for testing: set `SONORA_MAX_RECORDING_DURATION` (seconds) in scheme

## Layer Details

Presentation (MVVM)
- ViewModels (e.g., `RecordingViewModel`, `MemoListViewModel`, `MemoDetailViewModel`) expose state and call use cases.
- Views are simple and reactive; they don’t talk to repositories/services directly.

Domain
- Use cases encapsulate business logic: Recording, Transcription, Analysis, Memo management, Live Activity updates.
- Protocols define contracts for repositories and services.
- Models: Single memo model `Memo` (no adapters). Analysis domain models provide result structure.

Data
- Repositories isolate persistence and external dependencies (filesystem, AV, network) from domain logic:
  - `AudioRepositoryImpl` → Recording via `BackgroundAudioService`
  - `MemoRepositoryImpl` → Filesystem persistence and memo lifecycle
  - `TranscriptionRepositoryImpl`, `AnalysisRepositoryImpl`
- Services encapsulate transport logic: `TranscriptionService`, `AnalysisService`, `LiveActivityService`, `SystemNavigatorImpl`.

Core
- `DIContainer`: composition root; provides protocol-based access to shared instances.
- `OperationCoordinator`: registers, tracks, and cancels operations across the app.
- `EventBus` + handlers: decoupled event processing (e.g., starting/ending Live Activity for recording).
- `Logger` and `AppConfiguration`: consistent logging and runtime configuration.

## Dependency Injection

- DI occurs at the app edge via `DIContainer`.
- ViewModels use protocol-based dependencies. Convenience inits can resolve from the container, but core initializers accept protocols for testability.
- Repositories are composed in `DIContainer`; goal is constructor injection everywhere (minimize `.shared` calls).

## Concurrency & Operations

- Long-running work (recording, transcription, analysis) is tracked by `OperationCoordinator` with conflict detection.
- Delegates provide status updates; consumers can display progress, queue position, and metrics.
- Use structured logging for traceability and correlation across flows.

## Events

- `EventBus` publishes `AppEvent` (memo created, recording started/completed, transcription/analysis completed).
- Handlers (e.g., `LiveActivityEventHandler`, `MemoEventHandler`, `CalendarEventHandler`, `RemindersEventHandler`) react without coupling to feature code.

## Current Status & Metrics

- Clean Architecture: High compliance (Memo model unified; adapters removed)
  - Remaining: DI lookups in data layer convenience initializers; continue minimizing singletons
- MVVM: High compliance (primary screens use ViewModels, direct UI work kept minimal)
- Operations: OperationCoordinator in place with summaries/metrics APIs

## Gaps & Targeted Improvements

1) Constructor injection in Data layer
- Continue to replace `.shared` calls and container lookups inside repositories with injected dependencies.

2) Replace singletons with protocols
- `OperationCoordinatorProtocol` exists; prefer injection of protocol over direct `.shared`.

3) Reduce polling
- Replace `Timer.publish` in VMs with Combine publishers surfaced by repositories/services where feasible.

4) Orchestration boundaries
- Keep orchestration in use cases or event handlers; repositories should remain thin data sources.

5) Test surface
- Keep test harness use cases in test target or behind `#if DEBUG`.

## Best Practices

- Start with Domain: design use cases and protocols first.
- Keep ViewModels thin: they coordinate, they don’t own business logic.
- Inject dependencies: prefer protocol-based initializer injection.
- Track operations: register work with `OperationCoordinator` for consistent UX.
- Log meaningfully: use structured logs with correlation when helpful.
- Name entities simply: the domain entity is `Memo`; reserve suffixes for DTOs or persistence (e.g., `MemoDTO`, `MemoRecord`).

## Testing Notes

- Active guides: `docs/testing/` (background recording, enhanced flow, transcription integration)
- Historical fixes were consolidated into `ARCHIVE.md` for brevity.

## Appendix: File Map (Key Paths)

- Core: `Sonora/Core/*` (DI, Events, Concurrency, Logging, Configuration)
- Domain: `Sonora/Domain/UseCases/*`, `Sonora/Domain/Protocols/*`, `Sonora/Domain/Models/*`
- Data: `Sonora/Data/Repositories/*`, `Sonora/Data/Services/*`
- Presentation: `Sonora/Presentation/ViewModels/*`, `Sonora/Views/*`
