// Moved to Features/Memos/ViewModels
import Foundation
import Combine
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// ViewModel for handling memo detail functionality
/// Uses dependency injection for testability and clean architecture
@MainActor
final class MemoDetailViewModel: ObservableObject, OperationStatusDelegate, ErrorHandling {
    
    // MARK: - Dependencies
    private let playMemoUseCase: PlayMemoUseCaseProtocol
    private let startTranscriptionUseCase: StartTranscriptionUseCaseProtocol
    private let retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol
    private let getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol
    private let analyzeDistillUseCase: AnalyzeDistillUseCaseProtocol
    private let analyzeDistillParallelUseCase: AnalyzeDistillParallelUseCaseProtocol
    private let analyzeContentUseCase: AnalyzeContentUseCaseProtocol
    private let analyzeThemesUseCase: AnalyzeThemesUseCaseProtocol
    private let analyzeTodosUseCase: AnalyzeTodosUseCaseProtocol
    private let renameMemoUseCase: RenameMemoUseCaseProtocol
    private let createTranscriptShareFileUseCase: CreateTranscriptShareFileUseCaseProtocol
    private let createAnalysisShareFileUseCase: CreateAnalysisShareFileUseCaseProtocol
    private let deleteMemoUseCase: DeleteMemoUseCaseProtocol
    private let memoRepository: any MemoRepository // Still needed for state updates
    private let operationCoordinator: any OperationCoordinatorProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Current Memo
    private var currentMemo: Memo?
    
    // MARK: - Consolidated State
    
    /// Single source of truth for all UI state
    @Published var state = MemoDetailViewState()
    
    // MARK: - Non-UI State
    
    // Track temp files created for sharing so we can clean them up afterward
    private var lastShareTempURLs: [URL] = []
    private var pendingShareItems: [Any] = []
    
    // MARK: - Computed Properties
    
    /// Play button icon based on current playing state
    var playButtonIcon: String {
        state.audio.playButtonIcon
    }
    
    /// Whether transcription section should show completed state
    var isTranscriptionCompleted: Bool {
        state.transcription.isCompleted
    }
    
    /// Text content from completed transcription
    var transcriptionText: String? {
        state.transcription.state.text
    }

    /// Current playback time (seconds)
    var currentTime: TimeInterval { state.audio.currentTime }
    /// Current memo duration (seconds)
    var totalDuration: TimeInterval { state.audio.duration }

    /// Count of available analysis categories. With the simplified model,
    /// only Distill is considered.
    var analysisAvailableCount: Int {
        guard let memo = currentMemo else { return 0 }
        let repo = DIContainer.shared.analysisRepository()
        let hasDistill = repo.hasAnalysisResult(for: memo.id, mode: .distill)
            || repo.hasAnalysisResult(for: memo.id, mode: .distillSummary)
            || repo.hasAnalysisResult(for: memo.id, mode: .distillActions)
            || repo.hasAnalysisResult(for: memo.id, mode: .distillReflection)
        return hasDistill ? 1 : 0
    }

    /// Whether repository has any completed analysis for current memo
    var hasAnalysisAvailable: Bool { analysisAvailableCount > 0 }

    /// Latest analysis update timestamp from repository history
    var latestAnalysisUpdatedAt: Date? {
        guard let memo = currentMemo else { return nil }
        let history = DIContainer.shared.analysisRepository().getAnalysisHistory(for: memo.id)
        return history.map { $0.timestamp }.max()
    }

    /// Whether a cached Distill result exists in the repository for the current memo
    var hasCachedDistill: Bool {
        guard let memo = currentMemo else { return false }
        return DIContainer.shared.analysisRepository().hasAnalysisResult(for: memo.id, mode: .distill)
    }

    /// Restore cached Distill result into the UI if present
    func restoreCachedDistill() {
        guard let memo = currentMemo else { return }
        if let env: AnalyzeEnvelope<DistillData> = DIContainer.shared
            .analysisRepository()
            .getAnalysisResult(for: memo.id, mode: .distill, responseType: DistillData.self) {
            selectedAnalysisMode = .distill
            analysisResult = env.data
            analysisEnvelope = env
            isAnalyzing = false
            analysisCacheStatus = "✅ Restored from cache"
            analysisPerformanceInfo = "Restored on demand"
        }
    }

    /// Whether retry should be offered in UI
    var canRetryTranscription: Bool {
        if case .failed(let message) = transcriptionState {
            let lower = message.lowercased()
            if lower.contains("no speech detected") { return false }
            return message != TranscriptionError.noSpeechDetected.errorDescription
        }
        return false
    }
    
    // MARK: - Initialization
    
    init(
        playMemoUseCase: PlayMemoUseCaseProtocol,
        startTranscriptionUseCase: StartTranscriptionUseCaseProtocol,
        retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol,
        getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol,
        analyzeDistillUseCase: AnalyzeDistillUseCaseProtocol,
        analyzeDistillParallelUseCase: AnalyzeDistillParallelUseCaseProtocol,
        analyzeContentUseCase: AnalyzeContentUseCaseProtocol,
        analyzeThemesUseCase: AnalyzeThemesUseCaseProtocol,
        analyzeTodosUseCase: AnalyzeTodosUseCaseProtocol,
        renameMemoUseCase: RenameMemoUseCaseProtocol,
        createTranscriptShareFileUseCase: CreateTranscriptShareFileUseCaseProtocol,
        createAnalysisShareFileUseCase: CreateAnalysisShareFileUseCaseProtocol,
        deleteMemoUseCase: DeleteMemoUseCaseProtocol,
        memoRepository: any MemoRepository,
        operationCoordinator: any OperationCoordinatorProtocol
    ) {
        self.playMemoUseCase = playMemoUseCase
        self.startTranscriptionUseCase = startTranscriptionUseCase
        self.retryTranscriptionUseCase = retryTranscriptionUseCase
        self.getTranscriptionStateUseCase = getTranscriptionStateUseCase
        self.analyzeDistillUseCase = analyzeDistillUseCase
        self.analyzeDistillParallelUseCase = analyzeDistillParallelUseCase
        self.analyzeContentUseCase = analyzeContentUseCase
        self.analyzeThemesUseCase = analyzeThemesUseCase
        self.analyzeTodosUseCase = analyzeTodosUseCase
        self.renameMemoUseCase = renameMemoUseCase
        self.createTranscriptShareFileUseCase = createTranscriptShareFileUseCase
        self.createAnalysisShareFileUseCase = createAnalysisShareFileUseCase
        self.deleteMemoUseCase = deleteMemoUseCase
        self.memoRepository = memoRepository
        self.operationCoordinator = operationCoordinator
        
        setupBindings()
        setupOperationMonitoring()
        
        print("📝 MemoDetailViewModel: Initialized with dependency injection")
    }
    
    
    // MARK: - Setup Methods
    
    private func setupBindings() {
        // React to repository changes instead of polling
        memoRepository.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFromRepository()
            }
            .store(in: &cancellables)

        // Playback progress updates (throttled by repository timer)
        memoRepository.playbackProgressPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                guard let self = self, let memo = self.currentMemo, progress.memoId == memo.id else { return }
                self.state.audio.currentTime = progress.currentTime
                let dur = progress.duration.isFinite && progress.duration > 0 ? progress.duration : memo.duration
                self.state.audio.duration = dur
                if self.isPlaying != progress.isPlaying {
                    self.isPlaying = progress.isPlaying
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupOperationMonitoring() {
        // Register as delegate immediately to avoid missing early updates
        operationCoordinator.setStatusDelegate(self)

        // Update operation summaries every 2 seconds (fallback/debug)
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateOperationStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateOperationStatus() async {
        guard let currentMemo = currentMemo else { return }
        
        // Get operation summaries for current memo and extract IDs
        let memoSummaries = await operationCoordinator.getOperationSummaries(
            group: .all,
            filter: .active,
            for: currentMemo.id
        )
        memoOperationSummaries = memoSummaries.map { $0.operation.id }
        
        // Get all active operations system-wide (for debugging/monitoring)
        let allSummaries = await operationCoordinator.getOperationSummaries(
            group: .all,
            filter: .active,
            for: nil
        )
        activeOperations = allSummaries.map { $0.operation.id }
    }
    
    private func updateFromRepository() {
        guard let memo = currentMemo else { return }

        // Update transcription state
        let newTranscriptionState = getTranscriptionStateUseCase.execute(memo: memo)
        if !transcriptionState.isEqual(to: newTranscriptionState) {
            transcriptionState = newTranscriptionState
        }
        
        // Update playing state
        let newIsPlaying = memoRepository.playingMemo?.id == memo.id && memoRepository.isPlaying
        if isPlaying != newIsPlaying {
            isPlaying = newIsPlaying
        }
        // Update duration baseline from memo if not set yet
        if state.audio.duration == 0 {
            state.audio.duration = memo.duration
        }

        // Update language detection + moderation from metadata if available
        if let meta = DIContainer.shared.transcriptionRepository().getTranscriptionMetadata(for: memo.id) {
            if let lang = meta.detectedLanguage, let score = meta.qualityScore {
                updateLanguageDetection(language: lang, qualityScore: score)
            }
            if let flagged = meta.moderationFlagged { transcriptionModerationFlagged = flagged }
            if let cats = meta.moderationCategories { transcriptionModerationCategories = cats }
            if let service = meta.transcriptionService {
                state.transcription.service = service
            }
        }

        // Legacy auto-detection banners removed. Distill/Action Items surface detections inline.
    }
    
    // MARK: - Public Methods
    
    /// Configure the ViewModel with a memo
    func configure(with memo: Memo) {
        print("📝 MemoDetailViewModel: Configuring with memo: \(memo.filename)")
        self.currentMemo = memo
        self.currentMemoTitle = memo.displayName
        state.transcription.service = nil
        // Initialize audio duration/current for scrubber before playback starts
        state.audio.duration = memo.duration
        state.audio.currentTime = 0
        

        // Initial state update
        updateTranscriptionState(for: memo)
        setupPlayingState(for: memo)
        
        // Subscribe to transcription state changes for this memo to avoid race conditions
        DIContainer.shared.transcriptionRepository()
            .stateChangesPublisher(for: memo.id)
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                guard let self else { return }
                // Only update if the change pertains to current memo
                if self.currentMemo?.id == change.memoId {
                    self.transcriptionState = change.currentState
                }
            }
            .store(in: &cancellables)

        // Start monitoring operations for this memo
        Task {
            await updateOperationStatus()
        }
    }
    
    /// Start transcription for the current memo
    func startTranscription() {
        guard let memo = currentMemo else { return }
        print("📝 MemoDetailViewModel: Starting transcription for: \(memo.filename)")
        Task {
            do {
                try await startTranscriptionUseCase.execute(memo: memo)
            } catch {
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }
    
    /// Retry transcription for the current memo
    func retryTranscription() {
        guard let memo = currentMemo else { return }
        print("📝 MemoDetailViewModel: Retrying transcription for: \(memo.filename)")
        Task {
            do {
                try await retryTranscriptionUseCase.execute(memo: memo)
            } catch {
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }
    
    /// Play or pause the current memo
    func playMemo() {
        guard let memo = currentMemo else { return }
        print("📝 MemoDetailViewModel: Playing memo: \(memo.filename)")
        Task {
            do {
                try await playMemoUseCase.execute(memo: memo)
            } catch {
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }

    /// Seek within current memo playback
    func seek(to time: TimeInterval) {
        guard let memo = currentMemo else { return }
        memoRepository.seek(to: time, for: memo)
    }

    /// Skip forward/backward by delta seconds
    func skip(by delta: TimeInterval) {
        let cur = currentTime
        let dur = max(totalDuration, 0)
        guard dur > 0 else { return }
        let target = min(max(cur + delta, 0), dur)
        // If target equals current (already at boundary), no-op
        if abs(target - cur) < 0.01 {
            HapticManager.shared.playLightImpact()
            return
        }
        seek(to: target)
    }

    /// Delete the current memo with cascading cleanup
    func deleteCurrentMemo() {
        guard let memo = currentMemo else { return }
        print("🗑️ MemoDetailViewModel: Deleting memo: \(memo.filename)")
        isLoading = true
        Task {
            do {
                try await deleteMemoUseCase.execute(memo: memo)
                await MainActor.run {
                    self.isLoading = false
                    self.state.ui.didDeleteMemo = true
                    HapticManager.shared.playDeletionFeedback()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }
    
    /// Perform analysis with the specified mode
    func performAnalysis(mode: AnalysisMode, transcript: String) {
        guard let memo = currentMemo else {
            analysisError = "No memo selected for analysis"
            self.error = .analysisInvalidInput("No memo selected for analysis")
            return
        }
        
        print("📝 MemoDetailViewModel: Starting \(mode.displayName) analysis for memo \(memo.id)")
        
        isAnalyzing = true
        analysisError = nil
        selectedAnalysisMode = mode
        analysisResult = nil
        analysisEnvelope = nil
        analysisCacheStatus = "Checking cache..."
        analysisPerformanceInfo = nil
        
        Task {
            do {
                switch mode {
                case .distill:
                    if isParallelDistillEnabled {
                        await performParallelDistill(transcript: transcript, memoId: memo.id)
                    } else {
                        await performRegularDistill(transcript: transcript, memoId: memo.id)
                    }
                    
                // Distill component modes (not directly called from UI, but needed for switch exhaustiveness)
                case .distillSummary, .distillActions, .distillThemes, .distillReflection:
                    // These are handled internally by the parallel processing system
                    // For now, fall back to regular distill analysis
                    await performRegularDistill(transcript: transcript, memoId: memo.id)
                    
                case .analysis:
                    let envelope = try await analyzeContentUseCase.execute(transcript: transcript, memoId: memo.id)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Analysis completed (cached: \(envelope.latency_ms < 1000))")
                    }
                    
                case .themes:
                    let envelope = try await analyzeThemesUseCase.execute(transcript: transcript, memoId: memo.id)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Themes analysis completed (cached: \(envelope.latency_ms < 1000))")
                    }
                    
                case .todos:
                    let envelope = try await analyzeTodosUseCase.execute(transcript: transcript, memoId: memo.id)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Todos analysis completed (cached: \(envelope.latency_ms < 1000))")
                    }

                case .events:
                    // Use combined detection use case and surface events
                    let detection = try await DIContainer.shared.detectEventsAndRemindersUseCase().execute(transcript: transcript, memoId: memo.id)
                    await MainActor.run {
                        // Prefer detected events; fallback to empty to render a friendly state
                        let data = detection.events ?? EventsData(events: [])
                        analysisResult = data
                        // No standard envelope for events/reminders; header is omitted by design
                        analysisEnvelope = nil
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Events detection completed")
                    }

                case .reminders:
                    // Use combined detection use case and surface reminders
                    let detection = try await DIContainer.shared.detectEventsAndRemindersUseCase().execute(transcript: transcript, memoId: memo.id)
                    await MainActor.run {
                        // Prefer detected reminders; fallback to empty to render a friendly state
                        let data = detection.reminders ?? RemindersData(reminders: [])
                        analysisResult = data
                        analysisEnvelope = nil
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Reminders detection completed")
                    }
                }
            } catch {
                await MainActor.run {
                    analysisError = error.localizedDescription
                    self.error = ErrorMapping.mapError(error)
                    isAnalyzing = false
                }
            }
        }
    }
    
    /// Cancel specific operation by ID
    func cancelOperation(_ operationId: UUID) {
        Task {
            await operationCoordinator.cancelOperation(operationId)
            await updateOperationStatus() // Refresh status after cancellation
        }
    }
    
    /// Cancel all operations for current memo
    func cancelAllOperations() {
        guard let memo = currentMemo else { return }
        
        Task {
            let cancelledCount = await operationCoordinator.cancelAllOperations(for: memo.id)
            print("🚫 MemoDetailViewModel: Cancelled \(cancelledCount) operations for memo: \(memo.filename)")
            await updateOperationStatus()
        }
    }
    
    // MARK: - Title Renaming Methods
    
    /// Start renaming the memo title
    func startRenaming() {
        guard let memo = currentMemo else { return }
        print("📝 MemoDetailViewModel: Starting title rename for: \(memo.filename)")
        
        editedTitle = currentMemoTitle
        isRenamingTitle = true
        
        // Play light haptic feedback
        HapticManager.shared.playLightImpact()
    }
    
    /// Save the renamed title
    func saveRename() {
        guard let memo = currentMemo else { return }
        
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't save if title is empty or unchanged
        if trimmedTitle.isEmpty || trimmedTitle == currentMemoTitle {
            cancelRenaming()
            return
        }
        
        print("📝 MemoDetailViewModel: Saving rename to: '\(trimmedTitle)'")
        
        Task {
            do {
                try await renameMemoUseCase.execute(memo: memo, newTitle: trimmedTitle)
                await MainActor.run {
                    self.isRenamingTitle = false
                    self.editedTitle = ""
                    // Update title immediately and memo reference
                    self.currentMemoTitle = trimmedTitle
                    self.currentMemo = self.memoRepository.getMemo(by: memo.id)
                    HapticManager.shared.playSuccess()
                    print("📝 MemoDetailViewModel: Successfully renamed memo")
                }
            } catch {
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                    self.isRenamingTitle = false
                    self.editedTitle = ""
                    HapticManager.shared.playError()
                    print("❌ MemoDetailViewModel: Failed to rename memo: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Cancel renaming without saving
    func cancelRenaming() {
        print("📝 MemoDetailViewModel: Cancelling title rename")
        isRenamingTitle = false
        editedTitle = ""
    }
    
    // MARK: - Parallel Distill Methods
    
    private func performParallelDistill(transcript: String, memoId: UUID) async {
        print("📝 MemoDetailViewModel: Starting parallel Distill analysis")
        
        // Reset distill-specific state
        await MainActor.run {
            distillProgress = nil
            partialDistillData = nil
        }
        
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let envelope = try await analyzeDistillParallelUseCase.execute(
                transcript: transcript,
                memoId: memoId
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.distillProgress = progress
                    self?.partialDistillData = progress.completedResults
                }
            }
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            await MainActor.run {
                analysisResult = envelope.data
                analysisEnvelope = envelope
                isAnalyzing = false
                
                // Performance info for parallel execution
                let wasCached = duration < 1.0
                analysisCacheStatus = wasCached ? "✅ Loaded from cache" : "🚀 Parallel execution"
                analysisPerformanceInfo = "Parallel: \(envelope.latency_ms)ms, Total: \(Int(duration * 1000))ms"
                
                print("📝 MemoDetailViewModel: Parallel Distill analysis completed in \(Int(duration * 1000))ms")
            }
            
            // Record total duration metric
            PerformanceMetricsService.shared.recordDuration(
                name: "DistillTotalDuration",
                start: Date(timeIntervalSinceNow: -duration),
                extras: ["mode": "parallel"]
            )
            
        } catch {
            await MainActor.run {
                analysisError = error.localizedDescription
                self.error = ErrorMapping.mapError(error)
                isAnalyzing = false
                distillProgress = nil
                partialDistillData = nil
                print("❌ MemoDetailViewModel: Parallel Distill analysis failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func performRegularDistill(transcript: String, memoId: UUID) async {
        print("📝 MemoDetailViewModel: Starting regular Distill analysis")
        
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            let envelope = try await analyzeDistillUseCase.execute(transcript: transcript, memoId: memoId)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            await MainActor.run {
                analysisResult = envelope.data
                analysisEnvelope = envelope
                isAnalyzing = false
                
                // Determine cache status based on response time and latency
                let wasCached = duration < 1.0 || envelope.latency_ms < 1000
                analysisCacheStatus = wasCached ? "✅ Loaded from cache" : "🌐 Fresh from API"
                analysisPerformanceInfo = wasCached ?
                    "Response: \(Int(duration * 1000))ms" :
                    "API: \(envelope.latency_ms)ms, Total: \(Int(duration * 1000))ms"
                
                print("📝 MemoDetailViewModel: Regular Distill analysis completed (cached: \(wasCached))")
            }
            
            // Record total duration metric
            PerformanceMetricsService.shared.recordDuration(
                name: "DistillTotalDuration",
                start: Date(timeIntervalSinceNow: -duration),
                extras: ["mode": "regular"]
            )
            
        } catch {
            await MainActor.run {
                analysisError = error.localizedDescription
                self.error = ErrorMapping.mapError(error)
                isAnalyzing = false
                print("❌ MemoDetailViewModel: Regular Distill analysis failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateTranscriptionState(for memo: Memo) {
        let newState = getTranscriptionStateUseCase.execute(memo: memo)
        print("🔄 MemoDetailViewModel: Updating state for \(memo.filename)")
        print("🔄 MemoDetailViewModel: Current UI state: \(transcriptionState.statusText)")
        print("🔄 MemoDetailViewModel: New state from Repository: \(newState.statusText)")
        print("🔄 MemoDetailViewModel: New state is completed: \(newState.isCompleted)")
        
        transcriptionState = newState
    }
    
    private func setupPlayingState(for memo: Memo) {
        isPlaying = memoRepository.playingMemo?.id == memo.id && memoRepository.isPlaying
    }
    
    // MARK: - Lifecycle Methods
    
    func onViewAppear() {
        guard let memo = currentMemo else { return }
        print("📝 MemoDetailViewModel: View appeared for memo: \(memo.filename)")
        updateTranscriptionState(for: memo)
        setupPlayingState(for: memo)
        
        // Attempt to load language metadata to show banner if needed
        if let meta = DIContainer.shared.transcriptionRepository().getTranscriptionMetadata(for: memo.id),
           let lang = meta.detectedLanguage,
           let score = meta.qualityScore {
            updateLanguageDetection(language: lang, qualityScore: score)
        }

        // Auto-restore Distill results on appear without requiring another tap
        // Prefer Distill as the default mode when none is selected
        if selectedAnalysisMode == nil {
            selectedAnalysisMode = .distill
        }

        // If we are (or defaulted to) Distill and no result is currently in memory, restore from cache if available
        if selectedAnalysisMode == .distill, analysisResult == nil {
            if let env: AnalyzeEnvelope<DistillData> = DIContainer.shared
                .analysisRepository()
                .getAnalysisResult(for: memo.id, mode: .distill, responseType: DistillData.self) {
                analysisResult = env.data
                analysisEnvelope = env
                isAnalyzing = false
                analysisCacheStatus = "✅ Restored from cache"
                analysisPerformanceInfo = "Restored on appear"
            }
        }
    }
    
        /// Restore analysis UI state when returning from background or view re-appear
    func restoreAnalysisStateIfNeeded() {
        guard let memo = currentMemo else { return }
        if selectedAnalysisMode == .distill, analysisResult == nil {
            if let env: AnalyzeEnvelope<DistillData> = DIContainer.shared
                .analysisRepository()
                .getAnalysisResult(for: memo.id, mode: .distill, responseType: DistillData.self) {
                analysisResult = env.data
                analysisEnvelope = env
                isAnalyzing = false
                analysisCacheStatus = "✅ Restored from cache"
                analysisPerformanceInfo = "Restored on return"
            }
        }
    }


    func operationStatusDidUpdate(_ update: OperationStatusUpdate) async {
        guard update.operationType.category == .transcription,
              let memo = currentMemo,
              update.memoId == memo.id else { return }

        switch update.currentStatus {
        case .processing(let progress):
            await MainActor.run {
                self.transcriptionProgressPercent = progress?.percentage
                self.transcriptionProgressStep = progress?.currentStep ?? "Processing..."
            }
        default:
            break
        }
    }

    func operationDidComplete(_ operationId: UUID, memoId: UUID, operationType: OperationType) async {
        guard operationType.category == .transcription,
              let memo = currentMemo,
              memoId == memo.id else { return }
        await MainActor.run {
            self.transcriptionProgressPercent = nil
            self.transcriptionProgressStep = nil
            // Refresh language metadata and banner on completion
            if let meta = DIContainer.shared.transcriptionRepository().getTranscriptionMetadata(for: memo.id) {
                if let lang = meta.detectedLanguage, let score = meta.qualityScore {
                    self.updateLanguageDetection(language: lang, qualityScore: score)
                }
                if let flagged = meta.moderationFlagged { self.transcriptionModerationFlagged = flagged }
                if let cats = meta.moderationCategories { self.transcriptionModerationCategories = cats }
            }
        }
    }

    func operationDidFail(_ operationId: UUID, memoId: UUID, operationType: OperationType, error: Error) async {
        guard operationType.category == .transcription,
              let memo = currentMemo,
              memoId == memo.id else { return }
        await MainActor.run {
            self.transcriptionProgressPercent = nil
            self.transcriptionProgressStep = nil
        }
    }
}

// MARK: - TranscriptionState Extension for Comparison

private extension TranscriptionState {
    func isEqual(to other: TranscriptionState) -> Bool {
        switch (self, other) {
        case (.notStarted, .notStarted), (.inProgress, .inProgress):
            return true
        case (.completed(let text1), .completed(let text2)):
            return text1 == text2
        case (.failed(let error1), .failed(let error2)):
            return error1 == error2
        default:
            return false
        }
    }
}

// MARK: - Debug Helpers

extension MemoDetailViewModel {
    
    /// Get debug information about the current state
    var debugInfo: String {
        return """
        MemoDetailViewModel State:
        - currentMemo: \(currentMemo?.filename ?? "none")
        - transcriptionState: \(state.transcription.state.statusText)
        - isPlaying: \(state.audio.isPlaying)
        - isAnalyzing: \(state.analysis.isAnalyzing)
        - selectedAnalysisMode: \(state.analysis.selectedMode?.displayName ?? "none")
        - analysisError: \(state.analysis.error ?? "none")
        - error: \(state.ui.error?.localizedDescription ?? "none")
        - isLoading: \(state.ui.isLoading)
        """
    }
    
    // MARK: - ErrorHandling Protocol
    
    func retryLastOperation() {
        clearError()
        guard currentMemo != nil else { return }
        
        // Determine what operation to retry based on current state
        if state.transcription.state.isFailed {
            retryTranscription()
        } else if !state.transcription.state.isCompleted {
            startTranscription()
        }
    }
}

// MARK: - Language Banner API
extension MemoDetailViewModel {
    func updateLanguageDetection(language: String?, qualityScore: Double) {
        detectedLanguage = language
        guard let memo = currentMemo else { return }
        if languageBannerDismissedForMemo[memo.id] == true {
            showNonEnglishBanner = false
            return
        }

        // If user explicitly set a preferred language, don't warn when it matches
        if let pref = AppConfiguration.shared.preferredTranscriptionLanguage, let lang = language?.lowercased() {
            if pref == lang { showNonEnglishBanner = false; return }
        }

        if let lang = language, lang.lowercased() != "en", qualityScore > 0.6, AppConfiguration.shared.preferredTranscriptionLanguage == nil {
            showNonEnglishBanner = true
            languageBannerMessage = formatLanguageBannerMessage(for: lang)
        } else {
            showNonEnglishBanner = false
        }
    }

    private func formatLanguageBannerMessage(for languageCode: String) -> String {
        let languageName = WhisperLanguages.localizedDisplayName(for: languageCode)
        return "Detected language: \(languageName). Result may be less accurate."
    }

    func dismissLanguageBanner() {
        showNonEnglishBanner = false
        if let memo = currentMemo { languageBannerDismissedForMemo[memo.id] = true }
    }
    
    // MARK: - Share Functionality Methods
    
    /// Prepare share content based on selected options
    /// Build share items asynchronously, creating files as needed.
    private func buildShareItems() async -> [Any] {
        guard let memo = currentMemo else { return [] }
        var shareItems: [Any] = []
        lastShareTempURLs.removeAll()

        // Add audio file if selected (copy to temp with friendly name and wrap as provider)
        if shareAudioEnabled {
            let ext = memo.fileExtension
            let filename = memo.preferredShareableFileName + ".\(ext)"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            do {
                let fm = FileManager.default
                if fm.fileExists(atPath: tempURL.path) { try fm.removeItem(at: tempURL) }
                try fm.copyItem(at: memo.fileURL, to: tempURL)
                lastShareTempURLs.append(tempURL)
                if #available(iOS 14.0, *) {
                    let provider = NSItemProvider(item: tempURL as NSSecureCoding, typeIdentifier: UTType.mpeg4Audio.identifier)
                    provider.suggestedName = filename
                    shareItems.append(provider)
                } else {
                    shareItems.append(tempURL)
                }
            } catch {
                print("❌ MemoDetailViewModel: Failed creating temp audio share file: \(error.localizedDescription)")
                // Fallback to original URL if copy fails
                shareItems.append(memo.fileURL)
            }
        }

        // Add transcription as a .txt file if selected and available
        if shareTranscriptionEnabled, let transcriptText = transcriptionText {
            let formatted = formatTranscriptionForSharing(text: transcriptText)
            do {
                let url = try await createTranscriptShareFileUseCase.execute(memo: memo, text: formatted)
                lastShareTempURLs.append(url)
                if #available(iOS 14.0, *) {
                    let provider = NSItemProvider(item: url as NSSecureCoding, typeIdentifier: UTType.plainText.identifier)
                    provider.suggestedName = memo.preferredShareableFileName + ".txt"
                    shareItems.append(provider)
                } else {
                    shareItems.append(url)
                }
            } catch {
                print("❌ MemoDetailViewModel: Failed creating transcript file: \(error.localizedDescription)")
            }
        }

        // Add AI analysis as a consolidated .txt file if enabled and available
        if shareAnalysisEnabled {
            do {
                // With Distill-only analysis, restrict export to Distill content
                let url = try await createAnalysisShareFileUseCase.execute(memo: memo, includeTypes: [.distill])
                lastShareTempURLs.append(url)
                if #available(iOS 14.0, *) {
                    let provider = NSItemProvider(item: url as NSSecureCoding, typeIdentifier: UTType.plainText.identifier)
                    provider.suggestedName = memo.preferredShareableFileName + "_analysis.txt"
                    shareItems.append(provider)
                } else {
                    shareItems.append(url)
                }
            } catch {
                print("❌ MemoDetailViewModel: Failed creating analysis share file: \(error.localizedDescription)")
            }
        }

        return shareItems
    }
    
    /// Prepare share items asynchronously; presentation occurs after sheet dismiss.
    func shareSelectedContent() async {
        isPreparingShare = true
        let items = await buildShareItems()
        await MainActor.run {
            self.isPreparingShare = false
            self.pendingShareItems = items
            print("📤 MemoDetailViewModel: Prepared \(items.count) share item(s)")
        }
    }

    /// Called after Share sheet (SwiftUI) dismisses, to present the system share UI
    func presentPendingShareIfReady() {
        let items = pendingShareItems
        pendingShareItems.removeAll()
        guard !items.isEmpty else {
            print("📤 MemoDetailViewModel: No items to present after dismiss")
            return
        }
        presentShareSheet(with: items)
    }
    
    /// Present the native iOS share sheet with items
    private func presentShareSheet(with items: [Any]) {
        let activityController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // Clean up any temporary transcript files regardless of completion result
        activityController.completionWithItemsHandler = { [weak self] _, _, _, _ in
            guard let self = self else { return }
            let fm = FileManager.default
            for url in self.lastShareTempURLs {
                do { if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) } }
                catch { print("⚠️ MemoDetailViewModel: Failed to remove temp share file: \(error)") }
            }
            self.lastShareTempURLs.removeAll()
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true) {
                print("📤 MemoDetailViewModel: Share sheet presented successfully")
            }
        }
    }

    // Removed semaphore-based helper to avoid main-thread deadlocks
    
    /// Get formatted analysis text for sharing
    private func getShareableAnalysisText() -> String? {
        guard let memo = currentMemo else { return nil }
        
        let completedAnalyses = memo.analysisResults.filter { $0.isCompleted }
        guard !completedAnalyses.isEmpty else { return nil }
        
        var analysisText = "--- AI ANALYSIS ---\n\n"
        
        for analysis in completedAnalyses {
            switch analysis.type {
            case .distill:
                if let content = analysis.content, let summary = content.summary {
                    analysisText += "📝 DISTILL\n\(summary)\n\n"
                }
            case .summary:
                if let content = analysis.content, let summary = content.summary {
                    analysisText += "📝 SUMMARY\n\(summary)\n\n"
                }
            case .themes:
                if let content = analysis.content, !content.themes.isEmpty {
                    analysisText += "🏷️ THEMES\n"
                    for theme in content.themes {
                        analysisText += "• \(theme.name)\n"
                    }
                    analysisText += "\n"
                }
            case .actionItems:
                if let content = analysis.content, !content.actionItems.isEmpty {
                    analysisText += "✅ TO-DO\n"
                    for item in content.actionItems {
                        let status = item.isCompleted ? "✓" : "•"
                        analysisText += "\(status) \(item.text)\n"
                    }
                    analysisText += "\n"
                }
            case .keyPoints:
                if let content = analysis.content, !content.keyPoints.isEmpty {
                    analysisText += "🔍 KEY POINTS\n"
                    for point in content.keyPoints {
                        analysisText += "• \(point)\n"
                    }
                    analysisText += "\n"
                }
            }
        }
        
        return analysisText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Format transcription text for sharing
    private func formatTranscriptionForSharing(text: String) -> String {
        guard let memo = currentMemo else { return text }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let header = """
        \(currentMemoTitle)
        Recorded: \(dateFormatter.string(from: memo.creationDate))
        
        --- TRANSCRIPTION ---
        
        """
        
        return header + text
    }
}

// MARK: - Backward Compatibility Properties

extension MemoDetailViewModel {
    
    // MARK: - Transcription Properties
    var transcriptionState: TranscriptionState {
        get { state.transcription.state }
        set { state.transcription.state = newValue }
    }
    
    var transcriptionProgressPercent: Double? {
        get { state.transcription.progressPercent }
        set { state.transcription.progressPercent = newValue }
    }
    
    var transcriptionProgressStep: String? {
        get { state.transcription.progressStep }
        set { state.transcription.progressStep = newValue }
    }
    
    var transcriptionModerationFlagged: Bool {
        get { state.transcription.moderationFlagged }
        set { state.transcription.moderationFlagged = newValue }
    }
    
    var transcriptionModerationCategories: [String: Bool] {
        get { state.transcription.moderationCategories }
        set { state.transcription.moderationCategories = newValue }
    }

    var transcriptionServiceBadge: String? {
        state.transcription.serviceDisplayName
    }

    var transcriptionServiceIcon: String? {
        state.transcription.serviceIconName
    }
    
    // MARK: - Audio Properties  
    var isPlaying: Bool {
        get { state.audio.isPlaying }
        set { state.audio.isPlaying = newValue }
    }
    
    // MARK: - Analysis Properties
    var selectedAnalysisMode: AnalysisMode? {
        get { state.analysis.selectedMode }
        set { state.analysis.selectedMode = newValue }
    }
    
    var analysisResult: Any? {
        get { state.analysis.result }
        set { state.analysis.result = newValue }
    }
    
    var analysisEnvelope: Any? {
        get { state.analysis.envelope }
        set { state.analysis.envelope = newValue }
    }
    
    var isAnalyzing: Bool {
        get { state.analysis.isAnalyzing }
        set { state.analysis.isAnalyzing = newValue }
    }
    
    var analysisError: String? {
        get { state.analysis.error }
        set { state.analysis.error = newValue }
    }
    
    var analysisCacheStatus: String? {
        get { state.analysis.cacheStatus }
        set { state.analysis.cacheStatus = newValue }
    }
    
    var analysisPerformanceInfo: String? {
        get { state.analysis.performanceInfo }
        set { state.analysis.performanceInfo = newValue }
    }
    
    var isParallelDistillEnabled: Bool {
        get { state.analysis.isParallelDistillEnabled }
        set { state.analysis.isParallelDistillEnabled = newValue }
    }
    
    var distillProgress: DistillProgressUpdate? {
        get { state.analysis.distillProgress }
        set { state.analysis.distillProgress = newValue }
    }
    
    var partialDistillData: PartialDistillData? {
        get { state.analysis.partialDistillData }
        set { state.analysis.partialDistillData = newValue }
    }
    
    // MARK: - Language Properties
    var detectedLanguage: String? {
        get { state.language.detectedLanguage }
        set { state.language.detectedLanguage = newValue }
    }
    
    var showNonEnglishBanner: Bool {
        get { state.language.showNonEnglishBanner }
        set { state.language.showNonEnglishBanner = newValue }
    }
    
    var languageBannerMessage: String {
        get { state.language.bannerMessage }
        set { state.language.bannerMessage = newValue }
    }

    // Event/reminder detection banners removed; detections are shown via Action Items.
    
    func latestDetectedEvents() -> [EventsData.DetectedEvent] {
        guard let memo = currentMemo else { return [] }
        if let env: AnalyzeEnvelope<EventsData> = DIContainer.shared.analysisRepository().getAnalysisResult(for: memo.id, mode: .events, responseType: EventsData.self) {
            return env.data.events
        }
        return []
    }
    func latestDetectedReminders() -> [RemindersData.DetectedReminder] {
        guard let memo = currentMemo else { return [] }
        if let env: AnalyzeEnvelope<RemindersData> = DIContainer.shared.analysisRepository().getAnalysisResult(for: memo.id, mode: .reminders, responseType: RemindersData.self) {
            return env.data.reminders
        }
        return []
    }
    
    var languageBannerDismissedForMemo: [UUID: Bool] {
        get { state.language.bannerDismissedForMemo }
        set { state.language.bannerDismissedForMemo = newValue }
    }
    
    // MARK: - Title Editing Properties
    var isRenamingTitle: Bool {
        get { state.titleEditing.isRenaming }
        set { state.titleEditing.isRenaming = newValue }
    }
    
    var editedTitle: String {
        get { state.titleEditing.editedTitle }
        set { state.titleEditing.editedTitle = newValue }
    }
    
    var currentMemoTitle: String {
        get { state.titleEditing.currentMemoTitle }
        set { state.titleEditing.currentMemoTitle = newValue }
    }
    
    // MARK: - Share Properties
    var showShareSheet: Bool {
        get { state.share.showShareSheet }
        set { state.share.showShareSheet = newValue }
    }
    
    var shareAudioEnabled: Bool {
        get { state.share.audioEnabled }
        set { state.share.audioEnabled = newValue }
    }
    
    var shareTranscriptionEnabled: Bool {
        get { state.share.transcriptionEnabled }
        set { state.share.transcriptionEnabled = newValue }
    }
    
    var shareAnalysisEnabled: Bool {
        get { state.share.analysisEnabled }
        set { state.share.analysisEnabled = newValue }
    }
    
    var shareAnalysisSelectedTypes: Set<DomainAnalysisType> {
        get { state.share.analysisSelectedTypes }
        set { state.share.analysisSelectedTypes = newValue }
    }
    
    var isPreparingShare: Bool {
        get { state.share.isPreparingShare }
        set { state.share.isPreparingShare = newValue }
    }
    
    // MARK: - UI Properties
    var error: SonoraError? {
        get { state.ui.error }
        set { state.ui.error = newValue }
    }
    
    var isLoading: Bool {
        get { state.ui.isLoading }
        set { state.ui.isLoading = newValue }
    }
    
    // MARK: - Operation Properties (simplified access)
    var activeOperations: [UUID] {
        get { state.operations.activeOperations }
        set { state.operations.activeOperations = newValue }
    }
    
    var memoOperationSummaries: [UUID] {
        get { state.operations.memoOperationSummaries }
        set { state.operations.memoOperationSummaries = newValue }
    }

    // MARK: - Deletion/UI flags
    var didDeleteMemo: Bool {
        get { state.ui.didDeleteMemo }
        set { state.ui.didDeleteMemo = newValue }
    }
}
