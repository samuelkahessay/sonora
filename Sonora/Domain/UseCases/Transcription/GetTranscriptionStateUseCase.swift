import Foundation

/// Use case for getting transcription state of a memo
/// Encapsulates the business logic for retrieving transcription status
protocol GetTranscriptionStateUseCaseProtocol: Sendable {
    func execute(memo: Memo) async -> TranscriptionState
}

final class GetTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol, Sendable {

    // MARK: - Dependencies
    private let transcriptionRepository: any TranscriptionRepository
    private let logger: any LoggerProtocol

    // MARK: - Initialization
    init(transcriptionRepository: any TranscriptionRepository, logger: any LoggerProtocol = Logger.shared) {
        self.transcriptionRepository = transcriptionRepository
        self.logger = logger
    }

    // MARK: - Use Case Execution
    func execute(memo: Memo) async -> TranscriptionState {
        // Get current transcription state from repository
        let state = await transcriptionRepository.getTranscriptionState(for: memo.id)

        // Log state retrieval at debug level (reduces console noise)
        logger.debug("Retrieved transcription state for \(memo.filename): \(state.statusText)",
                     category: .transcription,
                     context: LogContext(additionalInfo: ["memoId": memo.id.uuidString]))

        return state
    }
}
