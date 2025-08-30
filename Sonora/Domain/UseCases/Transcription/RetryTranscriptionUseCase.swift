import Foundation

/// Use case for retrying transcription of a memo
/// Encapsulates the business logic for retrying failed transcriptions
protocol RetryTranscriptionUseCaseProtocol {
    func execute(memo: Memo) async throws
}

final class RetryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol {
    
    // MARK: - Dependencies
    private let transcriptionRepository: any TranscriptionRepository
    private let transcriptionAPI: any TranscriptionAPI
    
    // MARK: - Initialization
    init(transcriptionRepository: any TranscriptionRepository, transcriptionAPI: any TranscriptionAPI) {
        self.transcriptionRepository = transcriptionRepository
        self.transcriptionAPI = transcriptionAPI
    }
    
    // MARK: - Use Case Execution
    func execute(memo: Memo) async throws {
        print("🔄 RetryTranscriptionUseCase: Retrying transcription for memo: \(memo.filename)")
        
        // Check current transcription state
        let currentState = await MainActor.run {
            transcriptionRepository.getTranscriptionState(for: memo.id)
        }
        
        // Only allow retry if failed or not started
        guard currentState.isFailed || currentState.isNotStarted else {
            if currentState.isInProgress {
                print("⚠️ RetryTranscriptionUseCase: Transcription already in progress")
                throw TranscriptionError.alreadyInProgress
            } else if currentState.isCompleted {
                print("⚠️ RetryTranscriptionUseCase: Transcription already completed")
                throw TranscriptionError.alreadyCompleted
            } else {
                print("⚠️ RetryTranscriptionUseCase: Invalid state for retry")
                throw TranscriptionError.invalidState
            }
        }

        // Do not retry when the previous failure was "No speech detected"
        if case .failed(let message) = currentState, message == TranscriptionError.noSpeechDetected.errorDescription {
            print("⚠️ RetryTranscriptionUseCase: No speech detected previously; retry not allowed")
            throw TranscriptionError.noSpeechDetected
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: memo.fileURL.path) else {
            print("❌ RetryTranscriptionUseCase: Audio file not found")
            throw TranscriptionError.fileNotFound
        }
        
        // Set state to in-progress
        await MainActor.run {
            transcriptionRepository.saveTranscriptionState(.inProgress, for: memo.id)
        }
        
        do {
            // Perform transcription retry
            let transcriptionText = try await transcriptionAPI.transcribe(url: memo.fileURL)
            print("✅ RetryTranscriptionUseCase: Transcription retry completed for \(memo.filename)")
            print("💾 RetryTranscriptionUseCase: Text: \(transcriptionText.prefix(100))...")
            
            // Save completed transcription to repository
            await MainActor.run {
                let completedState = TranscriptionState.completed(transcriptionText)
                transcriptionRepository.saveTranscriptionState(completedState, for: memo.id)
                transcriptionRepository.saveTranscriptionText(transcriptionText, for: memo.id)
                
                print("💾 RetryTranscriptionUseCase: Transcription persisted to repository")
            }
            
        } catch {
            print("❌ RetryTranscriptionUseCase: Transcription retry failed for \(memo.filename): \(error)")
            
            // Save failed state to repository
            await MainActor.run {
                let failedState = TranscriptionState.failed(error.localizedDescription)
                transcriptionRepository.saveTranscriptionState(failedState, for: memo.id)
            }
            
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
}
