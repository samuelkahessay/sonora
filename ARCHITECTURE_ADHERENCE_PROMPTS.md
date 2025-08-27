# Architecture Adherence Prompts

This file contains a phased set of small, copy‑paste prompts you can give to your coding agent (one at a time) to reach full MVVM + Clean Architecture adherence. Each prompt is scoped, incremental, and includes clear acceptance criteria.

## 📊 **MIGRATION PROGRESS: 6/25 PHASES COMPLETED (24%)**

### ✅ **COMPLETED PHASES**
- **Phase 15**: Remove @EnvironmentObject MemoStore usage - **COMPLETE**
- **Phase 16**: ViewModels provide all needed state - **COMPLETE** 
- **Phase 21**: Remove legacy DI accessors - **PARTIALLY COMPLETE**
- **Phase 23**: Delete legacy views and test-only UIs - **COMPLETE**
- **Legacy Artifact Cleanup**: EventFlowTestHelper.swift, SonoraUITestsLaunchTests.swift - **COMPLETE**

### 🔄 **REMAINING: 19 HIGH-PRIORITY PHASES**

## Phase 1: Transcription Pipeline (decouple + event-driven)

1) Add transport protocol
- Action: Create `Sonora/Domain/Protocols/TranscriptionAPI.swift` with:
  ```swift
  protocol TranscriptionAPI { 
    func transcribe(url: URL) async throws -> String 
  }
  ```
  Make `Sonora/Services/TranscriptionService.swift` conform.
- Acceptance: Build compiles; no behavior change.

2) Use protocol in StartTranscriptionUseCase
- Action: In `StartTranscriptionUseCase`, replace concrete `TranscriptionService` dependency with `TranscriptionAPI`. Update initializer and references.
- Acceptance: Use case compiles; logic unchanged.

3) Use protocol in RetryTranscriptionUseCase
- Action: In `RetryTranscriptionUseCase`, depend on `TranscriptionAPI` instead of `TranscriptionService`.
- Acceptance: Use case compiles; logic unchanged.

4) Expose transport via DI
- Action: In `Core/DI/DIContainer.swift`, add a private `_transcriptionAPI: TranscriptionAPI` (backed by `TranscriptionService()`) and a public `func transcriptionAPI() -> TranscriptionAPI`.
- Acceptance: DI compiles; no call sites updated yet.

5) Stop constructing `TranscriptionService()` in ViewModels
- Action: In `MemoListViewModel` and `MemoDetailViewModel` convenience inits, replace ad‑hoc `TranscriptionService()` creation with `container.transcriptionAPI()` when constructing `StartTranscriptionUseCase`/`RetryTranscriptionUseCase`.
- Acceptance: ViewModels compile; behavior unchanged.

6) Read transcription state from repository only
- Action: In `MemoListViewModel`, remove `transcriptionService: TranscriptionServiceProtocol` dependency; add `transcriptionRepository: TranscriptionRepository`. Update `updateTranscriptionStates()` to use repository state (`transcriptionRepository.transcriptionStates`) and adjust convenience init to pass it.
- Acceptance: App compiles; list shows same statuses.

7) Auto-transcribe via event handler
- Action: In `Core/Events/MemoEventHandler.swift`, handle `.memoCreated` by resolving `StartTranscriptionUseCase` (via DI or by injecting a dependency into the handler) and calling `execute(memo:)`. Add guards to avoid duplicate starts (e.g., check repo state).
- Acceptance: Creating a new memo triggers transcription without repository calling TranscriptionManager.

8) Remove repo-driven auto-transcribe
- Action: In `Data/Repositories/MemoRepositoryImpl.swift`, remove usage of `DIContainer.shared.transcriptionManager()` in `triggerAutoTranscription(for:)` and delete the method; ensure `HandleNewRecordingUseCase` publishing `memoCreated` remains the trigger.
- Acceptance: No references to `TranscriptionManager` remain in Data layer; auto-transcription still works.

## Phase 2: Recording Pipeline (remove concrete casts)

9) Expand AudioRepository protocol for recording
- Action: In `Domain/Protocols/AudioRepository.swift`, add recording APIs: 
  - `func startRecording() async throws`
  - `func stopRecording()`
  - `var isRecording: Bool { get }`
  - `var recordingTime: TimeInterval { get }`
  - `func checkMicrophonePermissions()`
  - `var hasMicrophonePermission: Bool { get }`
- Acceptance: Protocol compiles.

10) Conform AudioRepositoryImpl to new API
- Action: In `Data/Repositories/AudioRepositoryImpl.swift`, implement the added protocol members by delegating to `BackgroundAudioService`.
- Acceptance: Compiles; start/stop still function via Background service.

11) Update AudioRecordingServiceWrapper to forward
- Action: In `Domain/UseCases/Recording/AudioRecordingServiceWrapper.swift`, implement new AudioRepository recording APIs by forwarding to `AudioRecordingService` (map names: `checkPermissions()` -> `checkMicrophonePermissions()`, `hasPermission` -> `hasMicrophonePermission`, etc.).
- Acceptance: Compiles with expanded protocol.

12) Use only AudioRepository in Start/Stop use cases
- Action: In `StartRecordingUseCase` and `StopRecordingUseCase`, remove all `as? AudioRepositoryImpl`/`AudioRecordingServiceWrapper` branches and call only the new `AudioRepository` APIs. Delete the legacy convenience inits that take `AudioRecordingService`.
- Acceptance: No concrete casts; use cases compile.

13) Provide AudioRepository via DI
- Action: In `DIContainer`, add `_audioRepository: AudioRepository = AudioRepositoryImpl()` and `func audioRepository() -> AudioRepository`.
- Acceptance: DI compiles.

14) Update RecordingViewModel to use repository-backed use cases
- Action: In `RecordingViewModel` convenience init, create `StartRecordingUseCase(audioRepository: container.audioRepository())` and `StopRecordingUseCase(audioRepository: container.audioRepository())`. Keep the existing `audioRecordingService` field temporarily for UI state to avoid behavior change.
- Acceptance: Compiles; record flow unchanged.

## Phase 3: Presentation Cleanup (remove legacy store + manager)

15) ✅ **COMPLETED**: Remove @EnvironmentObject MemoStore usage
- Action: In `RecordView`, `MemosView`, and `Views/MemoDetailView`, delete `@EnvironmentObject var memoStore` (and from previews). Remove `.environmentObject(MemoStore(...))` from `ContentView` preview.
- Acceptance: Build compiles; no runtime usage of `MemoStore` remains.
- **Status**: ✅ All @EnvironmentObject declarations removed from Views

16) ✅ **COMPLETED**: Ensure ViewModels provide all needed state
- Action: Verify Views read state only from their ViewModels. If any residual `memoStore` usage exists (e.g., in `MemoRowView`), replace it with ViewModel helpers already present.
- Acceptance: No references to `MemoStore` in Views.
- **Status**: ✅ All Views use @StateObject ViewModels exclusively

17) Remove ViewModel polling where feasible
- Action: For `MemoListViewModel` and `MemoDetailViewModel`, replace `Timer.publish` polling with Combine subscriptions to repository changes (e.g., add `var statesPublisher: AnyPublisher<[String: TranscriptionState], Never>` to `TranscriptionRepository` and `var memosPublisher: AnyPublisher<[Memo], Never>` to `MemoRepository`; implement in `*Impl` as `$prop.eraseToAnyPublisher()`).
- Acceptance: Compiles; lists and statuses still update without timers.

18) Switch RecordingViewModel UI state to AudioRepository
- Action: Replace reads of `audioRecordingService` state (isRecording, recordingTime, permission, countdown) with `audioRepository` equivalents where available; for countdown features not present in `BackgroundAudioService`, remove UI elements or stub with basic elapsed time.
- Acceptance: Compiles; record UI reflects repository state (note: countdown UI may be simplified).

19) Delete TranscriptionManager usage
- Action: Remove `Services/TranscriptionManager.swift` and all DI exposure (`_transcriptionManager`, `transcriptionService() -> TranscriptionServiceProtocol`, and related accessors). Update call sites to rely on repo/use cases (earlier prompts should have removed remaining uses).
- Acceptance: No references to `TranscriptionManager`; build compiles.

20) Remove MemoStore from DI and code
- Action: Delete DI `_memoStore`, its accessor methods, and any code paths using it. Remove `Sonora/MemoStore.swift` if no longer referenced.
- Acceptance: No references to `MemoStore`; build compiles.

## Phase 4: DI + Cleanup

21) 🔄 **PARTIALLY COMPLETED**: Remove legacy DI accessors
- Action: In `DIContainer`, remove `audioRecorder()`, `memoStore()`, `transcriptionManager()`, and any comments about "legacy compatibility". Ensure only protocol-returning accessors remain.
- Acceptance: DI minimal and protocol-first.
- **Status**: 🔄 Concrete accessors remain but properly documented as transitional

22) Normalize ViewModel convenience inits
- Action: Ensure all ViewModels’ convenience inits resolve only protocol-based dependencies from DI (no concrete service instantiation).
- Acceptance: Grep shows no `= TranscriptionService()` inits in ViewModels.

23) ✅ **COMPLETED**: Delete legacy views and test-only UIs
- Action: Remove `Views/Components/TranscriptionTestView.swift` and any references.
- Acceptance: Build compiles without test-only UI.
- **Status**: ✅ TranscriptionTestView.swift and other test artifacts removed

24) Remove `AudioRecorder.swift` and `AudioRecordingService` protocol if unused
- Action: If no references remain (thanks to AudioRepository), delete `Sonora/AudioRecorder.swift` and `Domain/Protocols/AudioRecordingService.swift`; also remove `AudioRecordingServiceWrapper.swift` once wrapper is unused.
- Acceptance: Project compiles with only `AudioRepository` used for recording.

25) Update LEGACY.md and README
- Action: Reflect removals and new architecture boundaries; mark migration complete.
- Acceptance: Docs match code; no references to removed artifacts.

## Optional Enhancements

26) Event-driven auto-transcribe refinement
- Action: Move `.memoCreated` handler to check repository state and queue conflict via `OperationCoordinator` before calling `StartTranscriptionUseCase`.
- Acceptance: Avoids double-start; respects operation constraints.

27) Tests for use cases
- Action: Add unit tests for `StartRecordingUseCase`, `StopRecordingUseCase`, `StartTranscriptionUseCase`, and `RetryTranscriptionUseCase` with mock protocols (`AudioRepository`, `TranscriptionAPI`, `TranscriptionRepository`).
- Acceptance: Tests compile and pass locally.

