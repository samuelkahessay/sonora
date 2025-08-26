import Foundation

/// Use case for getting transcription state of a memo
/// Encapsulates the business logic for retrieving transcription status
protocol GetTranscriptionStateUseCaseProtocol {
    func execute(memo: Memo) -> TranscriptionState
}

final class GetTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol {
    
    // MARK: - Dependencies
    private let transcriptionService: TranscriptionServiceProtocol
    
    // MARK: - Initialization
    init(transcriptionService: TranscriptionServiceProtocol) {
        self.transcriptionService = transcriptionService
    }
    
    // MARK: - Use Case Execution
    func execute(memo: Memo) -> TranscriptionState {
        // Get current transcription state
        let state = transcriptionService.getTranscriptionState(for: memo)
        
        // Log state retrieval for debugging
        print("📊 GetTranscriptionStateUseCase: Retrieved state for \(memo.filename): \(state.statusText)")
        
        return state
    }
}