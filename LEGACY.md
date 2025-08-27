# Legacy Components

This document lists files and APIs considered legacy or transitional in the Sonora iOS project. They exist for backward compatibility during the migration to the Clean Architecture structure described in README. Prefer new flows via Use Cases → ViewModels → Views and DI-managed services. Prioritize refactoring or removal once replacements are fully adopted.

## Legacy UI (Old Flow)
- `Sonora/RecordView.swift`: Legacy SwiftUI entry using `MemoStore` directly; superseded by Presentation/ViewModels + Views.
- `Sonora/MemosView.swift`: Legacy list UI bound to `MemoStore` via `@EnvironmentObject` (comments: “Keep for transition compatibility”).
- `Sonora/Views/Components/TranscriptionTestView.swift`: Prototype/test UI for transcription, not part of production flow.

## Legacy Services and Stores
- `Sonora/AudioRecorder.swift`: Concrete recorder used directly and through legacy pathways; Clean Architecture favors `AudioRepository` and `BackgroundAudioService` abstractions.
- `Sonora/MemoStore.swift`: App-wide observable store implementing repository-like behavior; DI notes it exists for legacy compatibility.
- `Sonora/Services/TranscriptionManager.swift`: Implements `TranscriptionServiceProtocol`; migration docs indicate intent to remove dependency in favor of repository-driven flow.

## Compatibility Bridges (Transitional)
- `Sonora/Domain/UseCases/Recording/AudioRecordingServiceWrapper.swift`: Temporary adapter to make `AudioRecordingService` usable via the `AudioRepository` interface. Marked as backward compatibility.
- `Sonora/Domain/Adapters/MemoAdapter.swift`: Backward-compat adapter between data `Memo` and domain `DomainMemo`.
- `Sonora/Domain/Adapters/TranscriptionAdapter.swift`: Backward-compat adapter bridging transcription data and domain models.
- `Sonora/Domain/Adapters/AnalysisAdapter.swift`: Backward-compat adapter bridging analysis data and domain models.

## Deprecated or Legacy APIs (in active files)
- `Sonora/Domain/UseCases/Recording/RequestMicrophonePermissionUseCase.swift`:
  - `executeLegacy() -> Bool` is marked `@available(*, deprecated, message: "Use async execute() method instead")`. Remove once all callers use the async `execute()`.

## DI Exposing Legacy for Migration
- `Sonora/Core/DI/DIContainer.swift`: Exposes concrete `AudioRecorder`, `TranscriptionManager`, and `MemoStore` “for legacy compatibility/gradual migration.” Treat as transitional access points rather than final architecture.

## Migration/Exploratory Docs (Indicators)
- `ARCHITECTURE_MIGRATION.md`: Describes migration to Clean Architecture.
- `TranscriptionRepositoryIntegration.md`: Calls out “Phase 3: Remove TranscriptionManager dependency.”
- `BuildErrorsFixes.md`, `SynchronousRecordingTest.md`, `EnhancedRecordingFlowTest.md`, `BackgroundRecordingTest.md`: Notes and experiments referencing legacy classes like `AudioRecordingServiceWrapper` and `AudioRecorder`.

## Rationale
- Explicit code comments include “temporary,” “backward compatibility,” or “deprecated.”
- Some files live outside the new Domain/Data/Presentation/Core flow or bypass Use Case → ViewModel → View patterns.
- New architecture relies on protocol-driven repositories/services and DI, superseding these legacy pathways.

