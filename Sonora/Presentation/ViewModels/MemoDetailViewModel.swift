import Foundation
import Combine
import SwiftUI

/// ViewModel for handling memo detail functionality
/// Uses dependency injection for testability and clean architecture
@MainActor
final class MemoDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let playMemoUseCase: PlayMemoUseCaseProtocol
    private let startTranscriptionUseCase: StartTranscriptionUseCaseProtocol
    private let retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol
    private let getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol
    private let analyzeTLDRUseCase: AnalyzeTLDRUseCaseProtocol
    private let analyzeContentUseCase: AnalyzeContentUseCaseProtocol
    private let analyzeThemesUseCase: AnalyzeThemesUseCaseProtocol
    private let analyzeTodosUseCase: AnalyzeTodosUseCaseProtocol
    private let memoRepository: MemoRepository // Still needed for state updates
    private let operationCoordinator: OperationCoordinator
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
    
    // MARK: - Operation Status
    @Published var activeOperations: [OperationSummary] = []
    @Published var memoOperationSummaries: [OperationSummary] = []
    
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
    
    // MARK: - Initialization
    
    init(
        playMemoUseCase: PlayMemoUseCaseProtocol,
        startTranscriptionUseCase: StartTranscriptionUseCaseProtocol,
        retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol,
        getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol,
        analyzeTLDRUseCase: AnalyzeTLDRUseCaseProtocol,
        analyzeContentUseCase: AnalyzeContentUseCaseProtocol,
        analyzeThemesUseCase: AnalyzeThemesUseCaseProtocol,
        analyzeTodosUseCase: AnalyzeTodosUseCaseProtocol,
        memoRepository: MemoRepository,
        operationCoordinator: OperationCoordinator = OperationCoordinator.shared
    ) {
        self.playMemoUseCase = playMemoUseCase
        self.startTranscriptionUseCase = startTranscriptionUseCase
        self.retryTranscriptionUseCase = retryTranscriptionUseCase
        self.getTranscriptionStateUseCase = getTranscriptionStateUseCase
        self.analyzeTLDRUseCase = analyzeTLDRUseCase
        self.analyzeContentUseCase = analyzeContentUseCase
        self.analyzeThemesUseCase = analyzeThemesUseCase
        self.analyzeTodosUseCase = analyzeTodosUseCase
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
        let transcriptionService = container.transcriptionService()
        let transcriptionAPI = container.transcriptionAPI()
        let logger = container.logger()
        
        // Use direct repository initialization to ensure real persistence
        let startTranscriptionUseCase = StartTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: transcriptionAPI
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
            analyzeTLDRUseCase: AnalyzeTLDRUseCase(analysisService: analysisService, analysisRepository: analysisRepository, logger: logger),
            analyzeContentUseCase: AnalyzeContentUseCase(analysisService: analysisService, analysisRepository: analysisRepository, logger: logger),
            analyzeThemesUseCase: AnalyzeThemesUseCase(analysisService: analysisService, analysisRepository: analysisRepository, logger: logger),
            analyzeTodosUseCase: AnalyzeTodosUseCase(analysisService: analysisService, analysisRepository: analysisRepository, logger: logger),
            memoRepository: memoRepository,
            operationCoordinator: container.operationCoordinator()
        )
    }
    
    // MARK: - Setup Methods
    
    private func setupBindings() {
        // Use timer to periodically sync with repository
        Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateFromRepository()
            }
            .store(in: &cancellables)
    }
    
    private func setupOperationMonitoring() {
        // Update operation summaries every 2 seconds
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
    }
    
    // MARK: - Public Methods
    
    /// Configure the ViewModel with a memo
    func configure(with memo: Memo) {
        print("📝 MemoDetailViewModel: Configuring with memo: \(memo.filename)")
        self.currentMemo = memo
        
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
                print("❌ MemoDetailViewModel: Failed to start transcription: \(error)")
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
                print("❌ MemoDetailViewModel: Failed to retry transcription: \(error)")
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
                print("❌ MemoDetailViewModel: Failed to play memo: \(error)")
            }
        }
    }
    
    /// Perform analysis with the specified mode
    func performAnalysis(mode: AnalysisMode, transcript: String) {
        guard let memo = currentMemo else {
            print("❌ MemoDetailViewModel: Cannot perform analysis - no current memo")
            analysisError = "No memo selected for analysis"
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
                case .tldr:
                    let startTime = CFAbsoluteTimeGetCurrent()
                    let envelope = try await analyzeTLDRUseCase.execute(transcript: transcript, memoId: memo.id)
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
                        
                        print("📝 MemoDetailViewModel: TLDR analysis completed (cached: \(wasCached))")
                    }
                    
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
                    isAnalyzing = false
                    print("❌ MemoDetailViewModel: Analysis failed: \(error)")
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
    }
    
    func onViewDisappear() {
        print("📝 MemoDetailViewModel: View disappeared")
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
        """
    }
}