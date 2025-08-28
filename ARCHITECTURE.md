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
- Recording: `BackgroundAudioService` (AV + background tasks) via `AudioRepositoryImpl`
- Transcription: `TranscriptionService` (network) + `TranscriptionRepository`
- Analysis: `AnalysisService` (network) + `AnalysisRepository`
- Operation Coordination: `OperationCoordinator` with conflict control and metrics
- Event Bus: App-wide event publication/subscription for decoupled features
- DI: `DIContainer` composes dependencies at the app edge

UI defaults:
- Native SwiftUI styling, no custom “glass” modifiers
- Global recording limit: 60 seconds with a 10-second countdown
- Override for testing: set `SONORA_MAX_RECORDING_DURATION` (seconds) in scheme

## Layer Details

Presentation (MVVM)
- ViewModels (e.g., `RecordingViewModel`, `MemoListViewModel`, `MemoDetailViewModel`) expose state and call use cases.
- Views are simple and reactive; they don’t talk to repositories/services directly.

Domain
- Use cases encapsulate business logic: Recording, Transcription, Analysis, Memo management, Live Activity updates.
- Protocols define contracts for repositories and services.

Data
- Repositories isolate persistence and external dependencies (filesystem, AV, network) from domain logic:
  - `AudioRepositoryImpl` → Recording via `BackgroundAudioService`
  - `TranscriptionRepositoryImpl`, `AnalysisRepositoryImpl`, `MemoRepositoryImpl`
- Services encapsulate transport logic (e.g., `TranscriptionService`).

Core
- `DIContainer`: composition root; provides protocol-based access to shared instances.
- `OperationCoordinator`: registers, tracks, and cancels operations across the app.
- `EventBus` + handlers: decoupled event processing (e.g., starting/ending Live Activity for recording).
- `Logger` and `AppConfiguration`: consistent logging and runtime configuration.

## Dependency Injection

- DI occurs at the app edge via `DIContainer`.
- ViewModels use protocol-based dependencies. Convenience inits can resolve from the container, but core initializers accept protocols for testability.
- Goal: move remaining DI lookups out of repositories and into top-level composition.

## Concurrency & Operations

- Long-running work (recording, transcription, analysis) is tracked by `OperationCoordinator` with conflict detection.
- Delegates provide status updates; consumers can display progress, queue position, and metrics.
- Use structured logging for traceability.

## Events

- `EventBus` publishes `AppEvent` (memo created, recording started/completed, transcription/analysis completed).
- Handlers (e.g., `LiveActivityEventHandler`) subscribe to events to update Live Activities without coupling to feature code.

## Current Status & Metrics

- Clean Architecture: ~65–70%
  - Strong separation and layering
  - Remaining: DI lookups in data layer; repository/service boundary cleanup; singleton usage
- MVVM: ~80–90%
  - All primary screens use ViewModels; some polling timers remain
- Overall: ~70–75%

## Gaps & Targeted Improvements

1) Constructor injection in Data layer
- Replace `DIContainer.shared` calls inside repositories with init-injected dependencies.

2) Replace singletons with protocols
- Introduce `OperationCoordinatorProtocol` and inject instead of using `.shared`.

3) Reduce polling
- Replace `Timer.publish` in VMs with Combine publishers from repositories (memos, transcription state, recording time) where feasible.

4) Orchestration boundaries
- Remove repository conformance to service protocols (e.g., transcription service). Move orchestration to use cases or dedicated event handlers.

5) Test surface
- Move test harness use cases into the test target or guard with `#if DEBUG`.

## Best Practices

- Start with Domain: design use cases and protocols first.
- Keep ViewModels thin: they coordinate, they don’t own business logic.
- Inject dependencies: prefer protocol-based initializer injection.
- Track operations: register work with `OperationCoordinator` for consistent UX.
- Log meaningfully: use structured logs with correlation when helpful.

## Testing Notes

- Active guides: `docs/testing/` (background recording, enhanced flow, transcription integration)
- Historical fixes were consolidated into `ARCHIVE.md` for brevity.

## Appendix: File Map (Key Paths)

- Core: `Sonora/Core/*` (DI, Events, Concurrency, Logging, Configuration)
- Domain: `Sonora/Domain/UseCases/*`, `Sonora/Domain/Protocols/*`, `Sonora/Domain/Models/*`
- Data: `Sonora/Data/Repositories/*`, `Sonora/Data/Services/*`
- Presentation: `Sonora/Presentation/ViewModels/*`, `Sonora/Views/*`

