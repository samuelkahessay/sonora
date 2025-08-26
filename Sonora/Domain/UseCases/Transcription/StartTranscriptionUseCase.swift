import Foundation

/// Use case for starting transcription of a memo
/// Encapsulates the business logic for initiating transcription
protocol StartTranscriptionUseCaseProtocol {
    func execute(memo: Memo) async throws
}

final class StartTranscriptionUseCase: StartTranscriptionUseCaseProtocol {
    
    // MARK: - Dependencies
    private let transcriptionService: TranscriptionServiceProtocol
    
    // MARK: - Initialization
    init(transcriptionService: TranscriptionServiceProtocol) {
        self.transcriptionService = transcriptionService
    }
    
    // MARK: - Use Case Execution
    func execute(memo: Memo) async throws {
        // Check if transcription is already in progress
        let currentState = transcriptionService.getTranscriptionState(for: memo)
        
        guard !currentState.isInProgress else {
            throw TranscriptionError.alreadyInProgress
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: memo.url.path) else {
            throw TranscriptionError.fileNotFound
        }
        
        // Start transcription
        transcriptionService.startTranscription(for: memo)
        
        print("📝 StartTranscriptionUseCase: Transcription started for memo: \(memo.filename)")
    }
}

// MARK: - Transcription Errors
enum TranscriptionError: LocalizedError {
    case alreadyInProgress
    case alreadyCompleted
    case invalidState
    case fileNotFound
    case invalidAudioFormat
    case networkError(String)
    case serviceUnavailable
    case transcriptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyInProgress:
            return "Transcription is already in progress for this memo"
        case .alreadyCompleted:
            return "Transcription has already been completed for this memo"
        case .invalidState:
            return "Invalid transcription state for retry operation"
        case .fileNotFound:
            return "Audio file not found"
        case .invalidAudioFormat:
            return "Invalid audio format for transcription"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serviceUnavailable:
            return "Transcription service is currently unavailable"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}