import Foundation

/// Use case for starting transcription of a memo
/// Encapsulates the business logic for initiating transcription
protocol StartTranscriptionUseCaseProtocol {
    func execute(memo: Memo) async throws
}

final class StartTranscriptionUseCase: StartTranscriptionUseCaseProtocol {
    
    // MARK: - Dependencies
    private let transcriptionRepository: TranscriptionRepository
    private let transcriptionService: TranscriptionService
    
    // MARK: - Initialization
    init(transcriptionRepository: TranscriptionRepository, transcriptionService: TranscriptionService) {
        self.transcriptionRepository = transcriptionRepository
        self.transcriptionService = transcriptionService
    }
    
    // MARK: - Factory Method (for backward compatibility)
    @MainActor
    static func create(transcriptionService: TranscriptionServiceProtocol) -> StartTranscriptionUseCase {
        // Use DI container to get repository
        let repository = DIContainer.shared.transcriptionRepository()
        return StartTranscriptionUseCase(transcriptionRepository: repository, transcriptionService: TranscriptionService())
    }
    
    
    // MARK: - Use Case Execution
    func execute(memo: Memo) async throws {
        print("📝 StartTranscriptionUseCase: Starting transcription for memo: \(memo.filename)")
        
        // Check if transcription is already in progress
        let currentState = await MainActor.run {
            transcriptionRepository.getTranscriptionState(for: memo.id)
        }
        
        guard !currentState.isInProgress else {
            print("⚠️ StartTranscriptionUseCase: Transcription already in progress")
            throw TranscriptionError.alreadyInProgress
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: memo.url.path) else {
            print("❌ StartTranscriptionUseCase: Audio file not found")
            throw TranscriptionError.fileNotFound
        }
        
        // Set state to in-progress
        await MainActor.run {
            transcriptionRepository.saveTranscriptionState(.inProgress, for: memo.id)
        }
        
        do {
            // Perform transcription
            let transcriptionText = try await transcriptionService.transcribe(url: memo.url)
            print("✅ StartTranscriptionUseCase: Transcription completed for \(memo.filename)")
            print("💾 StartTranscriptionUseCase: Text: \(transcriptionText.prefix(100))...")
            
            // Save completed transcription to repository
            await MainActor.run {
                let completedState = TranscriptionState.completed(transcriptionText)
                transcriptionRepository.saveTranscriptionState(completedState, for: memo.id)
                transcriptionRepository.saveTranscriptionText(transcriptionText, for: memo.id)
                
                print("💾 StartTranscriptionUseCase: Transcription persisted to repository")
            }
            
        } catch {
            print("❌ StartTranscriptionUseCase: Transcription failed for \(memo.filename): \(error)")
            
            // Save failed state to repository
            await MainActor.run {
                let failedState = TranscriptionState.failed(error.localizedDescription)
                transcriptionRepository.saveTranscriptionState(failedState, for: memo.id)
            }
            
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
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