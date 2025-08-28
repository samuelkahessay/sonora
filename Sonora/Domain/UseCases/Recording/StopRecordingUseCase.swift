import Foundation

/// Use case for stopping audio recording
/// Encapsulates the business logic for stopping recording sessions with background support
protocol StopRecordingUseCaseProtocol {
    func execute(memoId: UUID) async throws
}

final class StopRecordingUseCase: StopRecordingUseCaseProtocol {
    
    // MARK: - Dependencies
    private let audioRepository: AudioRepository
    private let operationCoordinator: OperationCoordinator
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    init(
        audioRepository: AudioRepository,
        operationCoordinator: OperationCoordinator = OperationCoordinator.shared,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.audioRepository = audioRepository
        self.operationCoordinator = operationCoordinator
        self.logger = logger
    }
    
    
    
    // MARK: - Use Case Execution
    func execute(memoId: UUID) async throws {
        let context = LogContext(additionalInfo: ["memoId": memoId.uuidString])
        
        logger.info("Stopping recording for memo: \(memoId)", category: .audio, context: context)
        
        // Check if recording operation exists for this memo
        let isRecordingActive = await operationCoordinator.isRecordingActive(for: memoId)
        guard isRecordingActive else {
            logger.warning("No active recording operation found for memo", category: .audio, context: context, error: nil)
            throw RecordingError.notRecording
        }
        
        // Get the recording operation to complete it later
        let activeOperations = await operationCoordinator.getActiveOperations(for: memoId)
        let recordingOperation = activeOperations.first { $0.type.category == .recording }
        
        do {
            // Check if AudioRepository supports recording
            if let audioRepoImpl = audioRepository as? AudioRepositoryImpl {
                await MainActor.run {
                    guard audioRepoImpl.isRecording else {
                        logger.warning("Audio repository shows no recording in progress", category: .audio, context: context, error: nil)
                        return
                    }
                    
                    // Stop background recording
                    audioRepoImpl.stopRecording()
                    logger.info("Background recording stopped successfully", category: .audio, context: context)
                }
            } else if let wrapper = audioRepository as? AudioRecordingServiceWrapper {
                // Use legacy AudioRecordingService
                let service = wrapper.service
                
                guard service.isRecording else {
                    throw RecordingError.notRecording
                }
                
                service.stopRecording()
                logger.info("Legacy recording stopped successfully", category: .audio, context: context)
            } else {
                throw RecordingError.backgroundRecordingNotSupported
            }
            
            // Complete the recording operation
            if let recordingOp = recordingOperation {
                await operationCoordinator.completeOperation(recordingOp.id)
                logger.debug("Recording operation completed: \(recordingOp.id)", category: .audio, context: context)
            }
            
        } catch {
            // Fail the recording operation if something went wrong
            if let recordingOp = recordingOperation {
                await operationCoordinator.failOperation(recordingOp.id, error: error)
                logger.error("Recording operation failed: \(recordingOp.id)", category: .audio, context: context, error: error)
            }
            throw error
        }
    }
}
