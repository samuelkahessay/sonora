import Foundation

/// Use case for getting transcription state of a memo
/// Encapsulates the business logic for retrieving transcription status
protocol GetTranscriptionStateUseCaseProtocol {
    func execute(memo: Memo) -> TranscriptionState
}

final class GetTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol {
    
    // MARK: - Dependencies
    private let transcriptionRepository: TranscriptionRepository
    
    // MARK: - Initialization
    init(transcriptionRepository: TranscriptionRepository) {
        self.transcriptionRepository = transcriptionRepository
    }
    
    // MARK: - Factory Method (for backward compatibility)
    @MainActor
    static func create(transcriptionService: TranscriptionServiceProtocol) -> GetTranscriptionStateUseCase {
        // Use DI container to get repository
        let repository = DIContainer.shared.transcriptionRepository()
        return GetTranscriptionStateUseCase(transcriptionRepository: repository)
    }
    
    
    // MARK: - Use Case Execution
    @MainActor
    func execute(memo: Memo) -> TranscriptionState {
        // Get current transcription state from repository
        let state = transcriptionRepository.getTranscriptionState(for: memo.id)
        
        // Log state retrieval for debugging
        print("📊 GetTranscriptionStateUseCase: Retrieved state for \(memo.filename): \(state.statusText)")
        
        return state
    }
}