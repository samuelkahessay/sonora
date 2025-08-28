import Foundation

/// Use case for starting transcription of a memo
/// Encapsulates the business logic for initiating transcription
protocol StartTranscriptionUseCaseProtocol {
    func execute(memo: Memo) async throws
}

final class StartTranscriptionUseCase: StartTranscriptionUseCaseProtocol {
    
    // MARK: - Dependencies
    private let transcriptionRepository: TranscriptionRepository
    private let transcriptionAPI: TranscriptionAPI
    private let eventBus: EventBusProtocol
    private let operationCoordinator: OperationCoordinator
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    init(
        transcriptionRepository: TranscriptionRepository, 
        transcriptionAPI: TranscriptionAPI, 
        eventBus: EventBusProtocol = EventBus.shared,
        operationCoordinator: OperationCoordinator = OperationCoordinator.shared,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.transcriptionRepository = transcriptionRepository
        self.transcriptionAPI = transcriptionAPI
        self.eventBus = eventBus
        self.operationCoordinator = operationCoordinator
        self.logger = logger
    }
    
    // MARK: - Use Case Execution
    func execute(memo: Memo) async throws {
        let context = LogContext(additionalInfo: [
            "memoId": memo.id.uuidString,
            "filename": memo.filename
        ])
        
        logger.info("Starting transcription for memo: \(memo.filename)", category: .transcription, context: context)
        
        // Check for operation conflicts (e.g., can't transcribe while recording same memo)
        guard await operationCoordinator.canStartTranscription(for: memo.id) else {
            logger.warning("Cannot start transcription - conflicting operation (recording) active", 
                          category: .transcription, context: context, error: nil)
            throw TranscriptionError.conflictingOperation
        }
        
        // Register transcription operation
        guard let operationId = await operationCoordinator.registerOperation(.transcription(memoId: memo.id)) else {
            logger.warning("Transcription rejected by operation coordinator", category: .transcription, context: context, error: nil)
            throw TranscriptionError.systemBusy
        }
        
        logger.debug("Transcription operation registered with ID: \(operationId)", category: .transcription, context: context)
        
        do {
            // Check if transcription is already in progress
            let currentState = await MainActor.run {
                transcriptionRepository.getTranscriptionState(for: memo.id)
            }
            
            guard !currentState.isInProgress else {
                await operationCoordinator.failOperation(operationId, error: TranscriptionError.alreadyInProgress)
                throw TranscriptionError.alreadyInProgress
            }
            
            // Check if file exists
            guard FileManager.default.fileExists(atPath: memo.url.path) else {
                await operationCoordinator.failOperation(operationId, error: TranscriptionError.fileNotFound)
                throw TranscriptionError.fileNotFound
            }
            
            // Set state to in-progress
            await MainActor.run {
                transcriptionRepository.saveTranscriptionState(.inProgress, for: memo.id)
            }
            
            // Perform transcription
            logger.info("Starting transcription service for file: \(memo.url.lastPathComponent)", category: .transcription, context: context)
            let transcriptionText = try await transcriptionAPI.transcribe(url: memo.url)
            
            logger.info("Transcription completed successfully", category: .transcription, context: LogContext(
                additionalInfo: [
                    "memoId": memo.id.uuidString,
                    "textLength": transcriptionText.count,
                    "previewText": String(transcriptionText.prefix(100))
                ]
            ))
            
            // Save completed transcription to repository
            await MainActor.run {
                let completedState = TranscriptionState.completed(transcriptionText)
                transcriptionRepository.saveTranscriptionState(completedState, for: memo.id)
                transcriptionRepository.saveTranscriptionText(transcriptionText, for: memo.id)
            }
            
            // Publish transcriptionCompleted event on main actor
            logger.debug("Publishing transcriptionCompleted event", category: .transcription, context: context)
            await MainActor.run { [eventBus] in
                eventBus.publish(.transcriptionCompleted(memoId: memo.id, text: transcriptionText))
            }
            
            // Complete the transcription operation
            await operationCoordinator.completeOperation(operationId)
            logger.debug("Transcription operation completed: \(operationId)", category: .transcription, context: context)
            
        } catch {
            logger.error("Transcription failed", category: .transcription, context: context, error: error)
            
            // Save failed state to repository
            await MainActor.run {
                let failedState = TranscriptionState.failed(error.localizedDescription)
                transcriptionRepository.saveTranscriptionState(failedState, for: memo.id)
            }
            
            // Fail the transcription operation
            await operationCoordinator.failOperation(operationId, error: error)
            
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
    case conflictingOperation
    case systemBusy
    
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
        case .conflictingOperation:
            return "Cannot start transcription while recording is in progress"
        case .systemBusy:
            return "System is busy - transcription queue is full"
        }
    }
}
