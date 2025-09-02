import Foundation

/// Use case for getting transcription state of a memo
/// Encapsulates the business logic for retrieving transcription status
protocol GetTranscriptionStateUseCaseProtocol {
    @MainActor
    func execute(memo: Memo) -> TranscriptionState
}

final class GetTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol {
    
    // MARK: - Dependencies
    private let transcriptionRepository: any TranscriptionRepository
    private let logger: any LoggerProtocol = Logger.shared
    
    // MARK: - Initialization
    init(transcriptionRepository: any TranscriptionRepository) {
        self.transcriptionRepository = transcriptionRepository
    }
    
    // MARK: - Use Case Execution
    @MainActor
    func execute(memo: Memo) -> TranscriptionState {
        // Get current transcription state from repository
        let state = transcriptionRepository.getTranscriptionState(for: memo.id)
        
        // Log state retrieval at debug level (reduces console noise)
        logger.debug("Retrieved transcription state for \(memo.filename): \(state.statusText)",
                     category: .transcription,
                     context: LogContext(additionalInfo: ["memoId": memo.id.uuidString]))
        
        return state
    }
}
