import Foundation
import Combine
import SwiftUI

/// ViewModel for handling memo detail functionality
/// Uses dependency injection for testability and clean architecture
@MainActor
final class MemoDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let memoRepository: MemoRepository
    private let analysisService: AnalysisServiceProtocol
    private let transcriptionService: TranscriptionServiceProtocol
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
        memoRepository: MemoRepository,
        analysisService: AnalysisServiceProtocol,
        transcriptionService: TranscriptionServiceProtocol
    ) {
        self.memoRepository = memoRepository
        self.analysisService = analysisService
        self.transcriptionService = transcriptionService
        
        setupBindings()
        
        print("📝 MemoDetailViewModel: Initialized with dependency injection")
    }
    
    /// Convenience initializer using DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            memoRepository: container.memoRepository(),
            analysisService: container.analysisService(),
            transcriptionService: container.transcriptionService()
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
        let newTranscriptionState = memoRepository.getTranscriptionState(for: memo)
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
        transcriptionService.startTranscription(for: memo)
    }
    
    /// Retry transcription for the current memo
    func retryTranscription() {
        guard let memo = currentMemo else { return }
        print("📝 MemoDetailViewModel: Retrying transcription for: \(memo.filename)")
        transcriptionService.retryTranscription(for: memo)
    }
    
    /// Play or pause the current memo
    func playMemo() {
        guard let memo = currentMemo else { return }
        print("📝 MemoDetailViewModel: Playing memo: \(memo.filename)")
        memoRepository.playMemo(memo)
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
                    let envelope = try await analysisService.analyzeTLDR(transcript: transcript)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: TLDR analysis completed")
                    }
                    
                case .analysis:
                    let envelope = try await analysisService.analyzeAnalysis(transcript: transcript)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Analysis completed")
                    }
                    
                case .themes:
                    let envelope = try await analysisService.analyzeThemes(transcript: transcript)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                        print("📝 MemoDetailViewModel: Themes analysis completed")
                    }
                    
                case .todos:
                    let envelope = try await analysisService.analyzeTodos(transcript: transcript)
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
        let newState = memoRepository.getTranscriptionState(for: memo)
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