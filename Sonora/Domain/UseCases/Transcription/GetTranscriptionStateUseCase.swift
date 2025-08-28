import Foundation

/// Use case for getting transcription state of a memo
/// Encapsulates the business logic for retrieving transcription status
protocol GetTranscriptionStateUseCaseProtocol {
    func execute(memo: DomainMemo) -> TranscriptionState
}

final class GetTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol {
    
    // MARK: - Dependencies
    private let transcriptionRepository: any TranscriptionRepository
    
    // MARK: - Initialization
    init(transcriptionRepository: any TranscriptionRepository) {
        self.transcriptionRepository = transcriptionRepository
    }
    
    // MARK: - Use Case Execution
    @MainActor
    func execute(memo: DomainMemo) -> TranscriptionState {
        // Get current transcription state from repository
        let state = transcriptionRepository.getTranscriptionState(for: memo.id)
        
        // Log state retrieval for debugging
        print("📊 GetTranscriptionStateUseCase: Retrieved state for \(memo.filename): \(state.statusText)")
        
        return state
    }
}
