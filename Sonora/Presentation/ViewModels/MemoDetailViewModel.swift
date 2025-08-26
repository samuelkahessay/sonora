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
        memoRepository: MemoRepository
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
        
        setupBindings()
        
        print("📝 MemoDetailViewModel: Initialized with dependency injection")
    }
    
    /// Convenience initializer using DIContainer
    convenience init() {
        let container = DIContainer.shared
        let memoRepository = container.memoRepository()
        let analysisService = container.analysisService()
        let transcriptionService = container.transcriptionService()
        
        self.init(
            playMemoUseCase: PlayMemoUseCase(memoRepository: memoRepository),
            startTranscriptionUseCase: StartTranscriptionUseCase(transcriptionService: transcriptionService),
            retryTranscriptionUseCase: RetryTranscriptionUseCase(transcriptionService: transcriptionService),
            getTranscriptionStateUseCase: GetTranscriptionStateUseCase(transcriptionService: transcriptionService),
            analyzeTLDRUseCase: AnalyzeTLDRUseCase(analysisService: analysisService),
            analyzeContentUseCase: AnalyzeContentUseCase(analysisService: analysisService),
            analyzeThemesUseCase: AnalyzeThemesUseCase(analysisService: analysisService),
            analyzeTodosUseCase: AnalyzeTodosUseCase(analysisService: analysisService),
            memoRepository: memoRepository
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
        print("📝 MemoDetailViewModel: Starting \(mode.displayName) analysis")
        
        isAnalyzing = true
        analysisError = nil
        selectedAnalysisMode = mode
        analysisResult = nil
        analysisEnvelope = nil
        
        Task {
            do {
                switch mode {
                case .tldr:
                    let envelope = try await analyzeTLDRUseCase.execute(transcript: transcript)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: TLDR analysis completed")
                    }
                    
                case .analysis:
                    let envelope = try await analyzeContentUseCase.execute(transcript: transcript)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Analysis completed")
                    }
                    
                case .themes:
                    let envelope = try await analyzeThemesUseCase.execute(transcript: transcript)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Themes analysis completed")
                    }
                    
                case .todos:
                    let envelope = try await analyzeTodosUseCase.execute(transcript: transcript)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Todos analysis completed")
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