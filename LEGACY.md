# Legacy and Transitional Notes

This document tracks legacy artifacts and transitional patterns. Several historical components have been removed; remaining items reflect current cleanup targets rather than old files.

## Removed Legacy Components
- Old `AudioRecorder` UI flow and wrapper adapter (migrated to `BackgroundAudioService` + `AudioRepositoryImpl`).
- Liquid glass UI modifiers and theme effects (reverted to native SwiftUI; theme skeleton retained).
- `@EnvironmentObject MemoStore` patterns (no current references).

## Transitional Patterns (Current Cleanup Targets)
- Data layer usage of `DIContainer.shared` inside repository constructors. Prefer constructor injection from the composition root.
- Repository conforming to service protocols (e.g., `TranscriptionServiceProtocol`) that blur boundaries. Prefer use cases or event handlers to orchestrate workflows.
- Global singletons (e.g., `OperationCoordinator.shared`) referenced directly. Introduce protocols and inject.
- Timer-based polling in ViewModels where repository publishers can be exposed.

## Active Migration References
- See `ARCHITECTURE_MIGRATION.md` and `ARCHITECTURE_ADHERENCE_PROMPTS.md` for step-by-step prompts and current status.

## Rationale
- Keep orchestration at the edges (use cases, event handlers), not inside repositories.
- Maintain clean dependency direction: Presentation → Use Cases → Repositories/Services.
- Use DI only at composition time; avoid container lookups in domain/data layers.
