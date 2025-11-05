import Combine
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// ViewModel for handling memo detail functionality
/// Uses dependency injection for testability and clean architecture
@MainActor
final class MemoDetailViewModel: ObservableObject, OperationStatusDelegate, ErrorHandling {

    // MARK: - Dependencies
    internal let playMemoUseCase: PlayMemoUseCaseProtocol
    internal let startTranscriptionUseCase: StartTranscriptionUseCaseProtocol
    internal let retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol
    internal let getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol
    internal let analyzeDistillUseCase: AnalyzeDistillUseCaseProtocol
    internal let analyzeLiteDistillUseCase: AnalyzeLiteDistillUseCaseProtocol
    internal let renameMemoUseCase: RenameMemoUseCaseProtocol
    internal let createTranscriptShareFileUseCase: CreateTranscriptShareFileUseCaseProtocol
    internal let createAnalysisShareFileUseCase: CreateAnalysisShareFileUseCaseProtocol
    internal let deleteMemoUseCase: DeleteMemoUseCaseProtocol
    internal let memoRepository: any MemoRepository // Still needed for state updates
    internal let operationCoordinator: any OperationCoordinatorProtocol
    internal let storeKitService: StoreKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Subscription State
    @Published var isProUser: Bool = false

    // MARK: - Analysis Cache State
    /// Cached analysis availability count (loaded asynchronously)
    @Published var analysisAvailableCount: Int = 0
    /// Latest analysis update timestamp (loaded asynchronously)
    @Published var latestAnalysisUpdatedAt: Date?
    /// Whether a cached Distill result exists (loaded asynchronously)
    @Published var hasCachedDistill: Bool = false

    // MARK: - SSE Streaming State
    /// Progressive distill update during SSE streaming
    @Published var distillProgress: AnalysisStreamingUpdate?
    /// Partial distill data accumulated during streaming
    @Published var partialDistillData: PartialDistillData?

    // MARK: - Current Memo
    internal var currentMemo: Memo?

    // MARK: - Lazy Cleaning Cache
    /// Cache for cleaned transcription text to avoid re-filtering on every access
    private var cleanedTextCache: [UUID: String] = [:]

    // MARK: - Consolidated State

    /// Single source of truth for all UI state
    @Published var state = MemoDetailViewState()

    // MARK: - Non-UI State

    // Track temp files created for sharing so we can clean them up afterward
    internal var lastShareTempURLs: [URL] = []
    internal var pendingShareItems: [Any] = []

    // MARK: - Computed Properties

    /// Play button icon based on current playing state
    var playButtonIcon: String {
        state.audio.playButtonIcon
    }

    /// Whether transcription section should show completed state
    var isTranscriptionCompleted: Bool {
        state.transcription.isCompleted
    }

    /// Text content from completed transcription (lazily cleaned for display)
    var transcriptionText: String? {
        guard let memo = currentMemo else { return nil }

        // Return cached cleaned text if available
        if let cached = cleanedTextCache[memo.id] {
            return cached
        }

        // Get original text from state
        guard let originalText = state.transcription.state.text else {
            return nil
        }

        // Lazy clean on first access
        let filter = DIContainer.shared.fillerWordFilter()
        let cleaned = filter.removeFillerWords(from: originalText)

        // Safety: never return empty if original had content (same logic as prepareTranscript)
        let final: String
        if cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
           !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            final = originalText
        } else {
            final = cleaned
        }

        // Cache for subsequent accesses
        cleanedTextCache[memo.id] = final
        return final
    }

    /// Current playback time (seconds)
    var currentTime: TimeInterval { state.audio.currentTime }
    /// Current memo duration (seconds)
    var totalDuration: TimeInterval { state.audio.duration }

    // Internal debug helper for cross-file extensions
    internal var debugCurrentMemoFilename: String {
        currentMemo?.filename ?? "none"
    }

    /// Whether repository has any completed analysis for current memo
    var hasAnalysisAvailable: Bool { analysisAvailableCount > 0 }

    /// Load analysis cache metadata asynchronously
    private func loadAnalysisCacheMetadata() {
        guard let memo = currentMemo else { return }
        Task {
            let repo = DIContainer.shared.analysisRepository()

            // Check each mode separately (can't use || with await)
            let hasDistillMode = await repo.hasAnalysisResult(for: memo.id, mode: .distill)
            let hasDistillSummary = await repo.hasAnalysisResult(for: memo.id, mode: .distillSummary)
            let hasDistillActions = await repo.hasAnalysisResult(for: memo.id, mode: .distillActions)
            let hasDistillReflection = await repo.hasAnalysisResult(for: memo.id, mode: .distillReflection)

            let hasDistill = hasDistillMode || hasDistillSummary || hasDistillActions || hasDistillReflection
            let count = hasDistill ? 1 : 0

            let history = await repo.getAnalysisHistory(for: memo.id)
            let latestTimestamp = history.map { $0.timestamp }.max()

            let hasCached = await repo.hasAnalysisResult(for: memo.id, mode: .distill)

            await MainActor.run {
                self.analysisAvailableCount = count
                self.latestAnalysisUpdatedAt = latestTimestamp
                self.hasCachedDistill = hasCached
            }
        }
    }

    /// Whether retry should be offered in UI
    var canRetryTranscription: Bool {
        if case let .failed(message) = transcriptionState {
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
        analyzeLiteDistillUseCase: AnalyzeLiteDistillUseCaseProtocol,
        renameMemoUseCase: RenameMemoUseCaseProtocol,
        createTranscriptShareFileUseCase: CreateTranscriptShareFileUseCaseProtocol,
        createAnalysisShareFileUseCase: CreateAnalysisShareFileUseCaseProtocol,
        deleteMemoUseCase: DeleteMemoUseCaseProtocol,
        memoRepository: any MemoRepository,
        operationCoordinator: any OperationCoordinatorProtocol,
        storeKitService: StoreKitServiceProtocol
    ) {
        self.playMemoUseCase = playMemoUseCase
        self.startTranscriptionUseCase = startTranscriptionUseCase
        self.retryTranscriptionUseCase = retryTranscriptionUseCase
        self.getTranscriptionStateUseCase = getTranscriptionStateUseCase
        self.analyzeDistillUseCase = analyzeDistillUseCase
        self.analyzeLiteDistillUseCase = analyzeLiteDistillUseCase
        self.renameMemoUseCase = renameMemoUseCase
        self.createTranscriptShareFileUseCase = createTranscriptShareFileUseCase
        self.createAnalysisShareFileUseCase = createAnalysisShareFileUseCase
        self.deleteMemoUseCase = deleteMemoUseCase
        self.memoRepository = memoRepository
        self.operationCoordinator = operationCoordinator
        self.storeKitService = storeKitService

        setupBindings()
        setupOperationMonitoring()

        print("📝 MemoDetailViewModel: Initialized with dependency injection")
    }

    // MARK: - Public Methods

    /// Current memo identifier (nil until configured)
    var memoId: UUID? {
        currentMemo?.id
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

    // MARK: - Distill Methods

    func performDistill(transcript: String, memoId: UUID) async {
        print("📝 MemoDetailViewModel: Starting Distill analysis (with SSE streaming)")

        // Reset streaming state
        await MainActor.run {
            distillProgress = nil
            partialDistillData = nil
        }

        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            let envelope = try await analyzeDistillUseCase.execute(
                transcript: transcript,
                memoId: memoId,
                isPro: storeKitService.isPro,
                progressHandler: { @MainActor [weak self] update in
                    // Update streaming state on main actor
                    self?.distillProgress = update
                    self?.partialDistillData = update.partialData
                    print("📡 MemoDetailViewModel: Progress update - \(update.completedCount)/\(update.totalCount)")
                }
            )
            let duration = CFAbsoluteTimeGetCurrent() - startTime

            await MainActor.run {
                analysisPayload = .distill(envelope.data, envelope)
                isAnalyzing = false

                // Clear streaming state on completion
                distillProgress = nil
                partialDistillData = nil

                // Determine cache status based on response time and latency
                let wasCached = duration < 1.0 || envelope.latency_ms < 1_000
                analysisCacheStatus = wasCached ? "✅ Loaded from cache" : "🌐 Fresh from API"
                analysisPerformanceInfo = wasCached ?
                    "Response: \(Int(duration * 1_000))ms" :
                    "API: \(envelope.latency_ms)ms, Total: \(Int(duration * 1_000))ms"

                print("📝 MemoDetailViewModel: Distill analysis completed (cached: \(wasCached), isPro: \(storeKitService.isPro))")

                // OPTIMIZATION: Skip redundant cache reload - metadata is already updated in use case
                // This saves 10-20ms per analysis
            }

            // Record total duration metric
            PerformanceMetricsService.shared.recordDuration(
                name: "DistillTotalDuration",
                start: Date(timeIntervalSinceNow: -duration),
                extras: ["mode": "unified", "isPro": String(storeKitService.isPro)]
            )

        } catch {
            await MainActor.run {
                analysisError = error.localizedDescription
                self.error = ErrorMapping.mapError(error)
                isAnalyzing = false
                print("❌ MemoDetailViewModel: Distill analysis failed: \(error.localizedDescription)")
            }
        }
    }

    func performLiteDistill(transcript: String, memoId: UUID) async {
        print("📝 MemoDetailViewModel: Starting Lite Distill analysis (Free tier)")

        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            let envelope = try await analyzeLiteDistillUseCase.execute(transcript: transcript, memoId: memoId)
            let duration = CFAbsoluteTimeGetCurrent() - startTime

            await MainActor.run {
                analysisPayload = .liteDistill(envelope.data, envelope)
                isAnalyzing = false

                // Cache detection (similar to regular Distill)
                let wasCached = duration < 1.0 || envelope.latency_ms < 1_000
                analysisCacheStatus = wasCached ? "✅ Loaded from cache" : "🌐 Fresh from API"
                analysisPerformanceInfo = wasCached ?
                    "Response: \(Int(duration * 1_000))ms" :
                    "API: \(envelope.latency_ms)ms, Total: \(Int(duration * 1_000))ms"

                print("📝 MemoDetailViewModel: Lite Distill analysis completed (cached: \(wasCached))")

                // OPTIMIZATION: Skip redundant cache reload - metadata is already updated in use case
                // This saves 10-20ms per analysis
            }

            // Record performance metrics for free tier
            PerformanceMetricsService.shared.recordDuration(
                name: "LiteDistillTotalDuration",
                start: Date(timeIntervalSinceNow: -duration),
                extras: ["tier": "free"]
            )

        } catch {
            await MainActor.run {
                analysisError = error.localizedDescription
                self.error = ErrorMapping.mapError(error)
                isAnalyzing = false
                print("❌ MemoDetailViewModel: Lite Distill analysis failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Methods

    private func updateTranscriptionState(for memo: Memo) async {
        let newState = await getTranscriptionStateUseCase.execute(memo: memo)
        print("🔄 MemoDetailViewModel: Updating state for \(memo.filename)")
        print("🔄 MemoDetailViewModel: Current UI state: \(transcriptionState.statusText)")
        print("🔄 MemoDetailViewModel: New state from Repository: \(newState.statusText)")
        print("🔄 MemoDetailViewModel: New state is completed: \(newState.isCompleted)")

        transcriptionState = newState
    }

    private func setupPlayingState(for memo: Memo) {
        isPlaying = memoRepository.playingMemo?.id == memo.id && memoRepository.isPlaying
    }

    /// Check if analysis result exists in cache (for latency optimization)
    /// Returns true if cached result exists, false otherwise
    func checkCachedAnalysis(memoId: UUID, mode: AnalysisMode) async -> Bool {
        let repository = DIContainer.shared.analysisRepository()
        switch mode {
        case .distill:
            return await repository.getAnalysisResult(for: memoId, mode: .distill, responseType: DistillData.self) != nil
        case .liteDistill:
            return await repository.getAnalysisResult(for: memoId, mode: .liteDistill, responseType: LiteDistillData.self) != nil
        default:
            return false
        }
    }

    // MARK: - Lifecycle Methods

    func onViewAppear() {
        guard let memo = currentMemo else { return }
        print("📝 MemoDetailViewModel: View appeared for memo: \(memo.filename)")
        Task {
            await updateTranscriptionState(for: memo)
        }
        setupPlayingState(for: memo)

        // Attempt to load language metadata to show banner if needed
        Task {
            if let meta = await DIContainer.shared.transcriptionRepository().getTranscriptionMetadata(for: memo.id),
               let lang = meta.detectedLanguage,
               let score = meta.qualityScore {
                updateLanguageDetection(language: lang, qualityScore: score)
            }
        }

        // Load analysis cache metadata
        loadAnalysisCacheMetadata()

        // Auto-restore Distill results on appear without requiring another tap
        // Prefer Distill as the default mode when none is selected
        if selectedAnalysisMode == nil {
            selectedAnalysisMode = .distill
        }

        // If we are (or defaulted to) Distill and no result is currently in memory, restore from cache if available
        if selectedAnalysisMode == .distill, analysisPayload == nil {
            Task {
                if let env: AnalyzeEnvelope<DistillData> = await DIContainer.shared
                    .analysisRepository()
                    .getAnalysisResult(for: memo.id, mode: .distill, responseType: DistillData.self) {
                    await MainActor.run {
                        self.analysisPayload = .distill(env.data, env)
                        self.isAnalyzing = false
                        self.analysisCacheStatus = "✅ Restored from cache"
                        self.analysisPerformanceInfo = "Restored on appear"
                    }
                }
            }
        }
    }

        /// Restore analysis UI state when returning from background or view re-appear
    func restoreAnalysisStateIfNeeded() async {
        guard let memo = currentMemo else { return }
        if selectedAnalysisMode == .distill, analysisPayload == nil {
            if let env: AnalyzeEnvelope<DistillData> = await DIContainer.shared
                .analysisRepository()
                .getAnalysisResult(for: memo.id, mode: .distill, responseType: DistillData.self) {
                await MainActor.run {
                    self.analysisPayload = .distill(env.data, env)
                    self.isAnalyzing = false
                    self.analysisCacheStatus = "✅ Restored from cache"
                    self.analysisPerformanceInfo = "Restored on return"
                }
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
        }
        // Refresh language metadata and banner on completion
        if let meta = await DIContainer.shared.transcriptionRepository().getTranscriptionMetadata(for: memo.id) {
            await MainActor.run {
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
// MARK: - Setup & Repository Wiring
extension MemoDetailViewModel {
    fileprivate func setupBindings() {
        // Subscribe to playback state changes
        memoRepository.playbackStatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] playbackState in
                guard let self = self, let memo = self.currentMemo else { return }
                let newIsPlaying = playbackState.playingMemo?.id == memo.id && playbackState.isPlaying
                if self.isPlaying != newIsPlaying {
                    self.isPlaying = newIsPlaying
                }
            }
            .store(in: &cancellables)

        // Subscribe to memo list changes to detect metadata updates (e.g., auto-title completion)
        memoRepository.memosPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, let memo = self.currentMemo else { return }

                // Update transcription state
                Task { @MainActor in
                    let newTranscriptionState = await self.getTranscriptionStateUseCase.execute(memo: memo)
                    if !self.transcriptionState.isEqual(to: newTranscriptionState) {
                        self.transcriptionState = newTranscriptionState
                    }
                }

                // Update duration baseline from memo if not set yet
                if self.state.audio.duration == 0 {
                    self.state.audio.duration = memo.duration
                }

                // Sync latest memo metadata (including auto-generated customTitle)
                if let latest = self.memoRepository.getMemo(by: memo.id) {
                    // If the title changed (e.g., auto-title completed), update local state
                    let latestDisplay = latest.displayName
                    if latestDisplay != self.currentMemoTitle {
                        self.currentMemoTitle = latestDisplay
                    }
                    // Keep an up-to-date reference to the memo
                    if latest != memo {
                        self.currentMemo = latest
                    }
                }

                // Update language detection + moderation from metadata if available
                Task { @MainActor in
                    if let meta = await DIContainer.shared.transcriptionRepository().getTranscriptionMetadata(for: memo.id) {
                        if let lang = meta.detectedLanguage, let score = meta.qualityScore {
                            self.updateLanguageDetection(language: lang, qualityScore: score)
                        }
                        if let flagged = meta.moderationFlagged { self.transcriptionModerationFlagged = flagged }
                        if let cats = meta.moderationCategories { self.transcriptionModerationCategories = cats }
                        if let service = meta.transcriptionService {
                            self.state.transcription.service = service
                        }
                    }
                }
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

        // Subscribe to Pro subscription status changes
        storeKitService.isProPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] isPro in
                self?.isProUser = isPro
            }
            .store(in: &cancellables)
    }

    fileprivate func setupOperationMonitoring() {
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

    func updateOperationStatus() async {
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

}

// MARK: - User Actions & Operations
extension MemoDetailViewModel {
    /// Configure the ViewModel with a memo
    func configure(with memo: Memo) {
        print("📝 MemoDetailViewModel: Configuring with memo: \(memo.filename)")

        // Clear cache for previous memo to avoid stale data
        if let prevMemo = currentMemo, prevMemo.id != memo.id {
            cleanedTextCache.removeValue(forKey: prevMemo.id)
        }

        self.currentMemo = memo
        self.currentMemoTitle = memo.displayName
        state.transcription.service = nil
        // Initialize audio duration/current for scrubber before playback starts
        state.audio.duration = memo.duration
        state.audio.currentTime = 0

        // Initial state update
        Task {
            await updateTranscriptionState(for: memo)
        }
        setupPlayingState(for: memo)

        // Load analysis cache metadata
        loadAnalysisCacheMetadata()

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

    /// Restore cached Distill result into the UI if present
    func restoreCachedDistill() async {
        guard let memo = currentMemo else { return }
        if let env: AnalyzeEnvelope<DistillData> = await DIContainer.shared
            .analysisRepository()
            .getAnalysisResult(for: memo.id, mode: .distill, responseType: DistillData.self) {
            await MainActor.run {
                self.selectedAnalysisMode = .distill
                self.analysisPayload = .distill(env.data, env)
                self.isAnalyzing = false
                self.analysisCacheStatus = "✅ Restored from cache"
                self.analysisPerformanceInfo = "Restored on demand"
            }
        }
    }
}
