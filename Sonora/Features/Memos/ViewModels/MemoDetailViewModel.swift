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
    private let memoRepository: any MemoRepository // Still needed for state updates
    private let operationCoordinator: any OperationCoordinatorProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Current Memo
    private var currentMemo: Memo?
    
    // MARK: - Published Properties
    
    // Transcription State
    @Published var transcriptionState: TranscriptionState = .notStarted
    
    // Audio Playback State
    @Published var isPlaying: Bool = false
    
    // Analysis State
    @Published var selectedAnalysisMode: AnalysisMode?
    @Published var analysisResult: Any?
    @Published var analysisEnvelope: Any?
    @Published var isAnalyzing: Bool = false
    @Published var analysisError: String?
    @Published var analysisCacheStatus: String?
    @Published var analysisPerformanceInfo: String?
    
    // Parallel Distill State
    @Published var isParallelDistillEnabled: Bool = true // Feature flag
    @Published var distillProgress: DistillProgressUpdate?
    @Published var partialDistillData: PartialDistillData?
    
    // MARK: - Operation Status
    @Published var activeOperations: [OperationSummary] = []
    @Published var memoOperationSummaries: [OperationSummary] = []
    @Published var transcriptionProgressPercent: Double? = nil
    @Published var transcriptionProgressStep: String? = nil

    // Language detection banner
    @Published var detectedLanguage: String? = nil
    @Published var showNonEnglishBanner: Bool = false
    @Published var languageBannerMessage: String = ""
    private var languageBannerDismissedForMemo: [UUID: Bool] = [:]
    
    // Moderation state for transcription
    @Published var transcriptionModerationFlagged: Bool = false
    @Published var transcriptionModerationCategories: [String: Bool] = [:]
    
    // Error handling
    @Published var error: SonoraError?
    @Published var isLoading: Bool = false
    
    // Title renaming state
    @Published var isRenamingTitle: Bool = false
    @Published var editedTitle: String = ""
    @Published var currentMemoTitle: String = ""
    
    // Share functionality state
    @Published var showShareSheet: Bool = false
    @Published var shareAudioEnabled: Bool = true
    @Published var shareTranscriptionEnabled: Bool = false
    @Published var shareAnalysisEnabled: Bool = false
    @Published var shareAnalysisSelectedTypes: Set<DomainAnalysisType> = []
    
    // Track temp files created for sharing so we can clean them up afterward
    private var lastShareTempURLs: [URL] = []
    @Published var isPreparingShare: Bool = false
    private var pendingShareItems: [Any] = []
    
    // MARK: - Computed Properties
    
    /// Play button icon based on current playing state
    var playButtonIcon: String {
        isPlaying ? "pause.fill" : "play.fill"
    }
    
    /// Whether transcription section should show completed state
    var isTranscriptionCompleted: Bool {
        transcriptionState.isCompleted
    }
    
    /// Text content from completed transcription
    var transcriptionText: String? {
        transcriptionState.text
    }

    /// Count of available analysis categories (Distill, Analysis, Themes, Todos), consolidated across sub-modes
    var analysisAvailableCount: Int {
        guard let memo = currentMemo else { return 0 }
        let repo = DIContainer.shared.analysisRepository()
        var count = 0
        // Distill present if full or any component exists
        let hasDistill = repo.hasAnalysisResult(for: memo.id, mode: .distill)
            || repo.hasAnalysisResult(for: memo.id, mode: .distillSummary)
            || repo.hasAnalysisResult(for: memo.id, mode: .distillThemes)
            || repo.hasAnalysisResult(for: memo.id, mode: .distillActions)
            || repo.hasAnalysisResult(for: memo.id, mode: .distillReflection)
        if hasDistill { count += 1 }
        if repo.hasAnalysisResult(for: memo.id, mode: .analysis) { count += 1 }
        if repo.hasAnalysisResult(for: memo.id, mode: .themes) { count += 1 }
        if repo.hasAnalysisResult(for: memo.id, mode: .todos) { count += 1 }
        return count
    }

    /// Whether repository has any completed analysis for current memo
    var hasAnalysisAvailable: Bool { analysisAvailableCount > 0 }

    /// Latest analysis update timestamp from repository history
    var latestAnalysisUpdatedAt: Date? {
        guard let memo = currentMemo else { return nil }
        let history = DIContainer.shared.analysisRepository().getAnalysisHistory(for: memo.id)
        return history.map { $0.timestamp }.max()
    }

    /// Whether retry should be offered in UI
    var canRetryTranscription: Bool {
        if case .failed(let message) = transcriptionState {
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
        self.memoRepository = memoRepository
        self.operationCoordinator = operationCoordinator
        
        setupBindings()
        setupOperationMonitoring()
        
        print("📝 MemoDetailViewModel: Initialized with dependency injection")
    }
    
    /// Convenience initializer using DIContainer
    /// CRITICAL FIX: Uses proper dependency injection following Clean Architecture
    convenience init() {
        let container = DIContainer.shared
        let memoRepository = container.memoRepository()
        let analysisService = container.analysisService()
        let analysisRepository = container.analysisRepository()
        let transcriptionRepository = container.transcriptionRepository()
        let transcriptionAPI = container.transcriptionAPI()
        let logger = container.logger()
        
        // Use direct repository initialization to ensure real persistence
        let startTranscriptionUseCase = StartTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: transcriptionAPI,
            eventBus: container.eventBus(),
            operationCoordinator: container.operationCoordinator(),
            moderationService: container.moderationService()
        )
        let retryTranscriptionUseCase = RetryTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: transcriptionAPI
        )
        let getTranscriptionStateUseCase = GetTranscriptionStateUseCase(
            transcriptionRepository: transcriptionRepository
        )
        
        self.init(
            playMemoUseCase: PlayMemoUseCase(memoRepository: memoRepository),
            startTranscriptionUseCase: startTranscriptionUseCase,
            retryTranscriptionUseCase: retryTranscriptionUseCase,
            getTranscriptionStateUseCase: getTranscriptionStateUseCase,
            analyzeDistillUseCase: AnalyzeDistillUseCase(analysisService: analysisService, analysisRepository: analysisRepository, logger: logger, eventBus: container.eventBus(), operationCoordinator: container.operationCoordinator()),
            analyzeDistillParallelUseCase: AnalyzeDistillParallelUseCase(analysisService: analysisService, analysisRepository: analysisRepository, logger: logger, eventBus: container.eventBus(), operationCoordinator: container.operationCoordinator()),
            analyzeContentUseCase: AnalyzeContentUseCase(analysisService: analysisService, analysisRepository: analysisRepository, logger: logger, eventBus: container.eventBus()),
            analyzeThemesUseCase: AnalyzeThemesUseCase(analysisService: analysisService, analysisRepository: analysisRepository, logger: logger, eventBus: container.eventBus()),
            analyzeTodosUseCase: AnalyzeTodosUseCase(analysisService: analysisService, analysisRepository: analysisRepository, logger: logger, eventBus: container.eventBus()),
            renameMemoUseCase: RenameMemoUseCase(memoRepository: memoRepository),
            createTranscriptShareFileUseCase: container.createTranscriptShareFileUseCase(),
            createAnalysisShareFileUseCase: container.createAnalysisShareFileUseCase(),
            memoRepository: memoRepository,
            operationCoordinator: container.operationCoordinator()
        )
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
    }
    
    private func setupOperationMonitoring() {
        // Set self as progress/status delegate to get live updates
        Task { [weak self] in
            guard let self else { return }
            await operationCoordinator.setStatusDelegate(self)
        }

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
        
        // Get operation summaries for current memo
        memoOperationSummaries = await operationCoordinator.getOperationSummaries(
            group: .all,
            filter: .active,
            for: currentMemo.id
        )
        
        // Get all active operations system-wide (for debugging/monitoring)
        activeOperations = await operationCoordinator.getOperationSummaries(
            group: .all,
            filter: .active,
            for: nil
        )
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

        // Update language detection + moderation from metadata if available
        if let meta = DIContainer.shared.transcriptionRepository().getTranscriptionMetadata(for: memo.id) {
            if let lang = meta["detectedLanguage"] as? String,
               let score = meta["qualityScore"] as? Double {
                updateLanguageDetection(language: lang, qualityScore: score)
            }
            if let flagged = meta["moderationFlagged"] as? Bool { transcriptionModerationFlagged = flagged }
            if let cats = meta["moderationCategories"] as? [String: Bool] { transcriptionModerationCategories = cats }
        }
    }
    
    // MARK: - Public Methods
    
    /// Configure the ViewModel with a memo
    func configure(with memo: Memo) {
        print("📝 MemoDetailViewModel: Configuring with memo: \(memo.filename)")
        self.currentMemo = memo
        self.currentMemoTitle = memo.displayName
        
        // Initial state update
        updateTranscriptionState(for: memo)
        setupPlayingState(for: memo)
        
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
           let lang = meta["detectedLanguage"] as? String,
           let score = meta["qualityScore"] as? Double {
            updateLanguageDetection(language: lang, qualityScore: score)
        }
    }
    
    func onViewDisappear() {
        print("📝 MemoDetailViewModel: View disappeared")
        Task { [weak self] in
            guard let self else { return }
            await operationCoordinator.setStatusDelegate(nil)
        }
    }

    // MARK: - OperationStatusDelegate
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
                if let lang = meta["detectedLanguage"] as? String,
                   let score = meta["qualityScore"] as? Double {
                    self.updateLanguageDetection(language: lang, qualityScore: score)
                }
                if let flagged = meta["moderationFlagged"] as? Bool { self.transcriptionModerationFlagged = flagged }
                if let cats = meta["moderationCategories"] as? [String: Bool] { self.transcriptionModerationCategories = cats }
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
        - transcriptionState: \(transcriptionState.statusText)
        - isPlaying: \(isPlaying)
        - isAnalyzing: \(isAnalyzing)
        - selectedAnalysisMode: \(selectedAnalysisMode?.displayName ?? "none")
        - analysisError: \(analysisError ?? "none")
        - error: \(error?.localizedDescription ?? "none")
        - isLoading: \(isLoading)
        """
    }
    
    // MARK: - ErrorHandling Protocol
    
    func retryLastOperation() {
        clearError()
        guard currentMemo != nil else { return }
        
        // Determine what operation to retry based on current state
        if transcriptionState.isFailed {
            retryTranscription()
        } else if !transcriptionState.isCompleted {
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
                let types: Set<DomainAnalysisType>? = shareAnalysisSelectedTypes.isEmpty ? nil : shareAnalysisSelectedTypes
                let url = try await createAnalysisShareFileUseCase.execute(memo: memo, includeTypes: types)
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
