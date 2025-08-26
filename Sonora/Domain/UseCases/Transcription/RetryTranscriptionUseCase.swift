import Foundation

/// Use case for retrying transcription of a memo
/// Encapsulates the business logic for retrying failed transcriptions
protocol RetryTranscriptionUseCaseProtocol {
    func execute(memo: Memo) async throws
}

final class RetryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol {
    
    // MARK: - Dependencies
    private let transcriptionService: TranscriptionServiceProtocol
    
    // MARK: - Initialization
    init(transcriptionService: TranscriptionServiceProtocol) {
        self.transcriptionService = transcriptionService
    }
    
    // MARK: - Use Case Execution
    func execute(memo: Memo) async throws {
        // Check current transcription state
        let currentState = transcriptionService.getTranscriptionState(for: memo)
        
        // Only allow retry if failed or not started
        guard currentState.isFailed || currentState.isNotStarted else {
            if currentState.isInProgress {
                throw TranscriptionError.alreadyInProgress
            } else if currentState.isCompleted {
                throw TranscriptionError.alreadyCompleted
            } else {
                throw TranscriptionError.invalidState
            }
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: memo.url.path) else {
            throw TranscriptionError.fileNotFound
        }
        
        // Retry transcription
        transcriptionService.retryTranscription(for: memo)
        
        print("🔄 RetryTranscriptionUseCase: Transcription retry started for memo: \(memo.filename)")
    }
}

