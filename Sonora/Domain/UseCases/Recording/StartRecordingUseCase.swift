import Foundation

/// Use case for starting audio recording
/// Encapsulates the business logic for initiating recording sessions with background support
protocol StartRecordingUseCaseProtocol {
    func execute() async throws -> UUID?
}

final class StartRecordingUseCase: StartRecordingUseCaseProtocol {
    
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
    
    // MARK: - Convenience Initializer (for backward compatibility)
    convenience init(audioRecordingService: AudioRecordingService) {
        // Create a wrapper that implements AudioRepository protocol
        // This is a temporary solution for backward compatibility
        self.init(
            audioRepository: AudioRecordingServiceWrapper(service: audioRecordingService),
            operationCoordinator: OperationCoordinator.shared,
            logger: Logger.shared
        )
    }
    
    // MARK: - Use Case Execution
    func execute() async throws -> UUID? {
        // Generate memo ID for this recording session
        let memoId = UUID()
        let context = LogContext(additionalInfo: ["memoId": memoId.uuidString])
        
        logger.info("Starting recording for memo: \(memoId)", category: .audio, context: context)
        
        // Register recording operation with coordinator
        guard let operationId = await operationCoordinator.registerOperation(.recording(memoId: memoId)) else {
            logger.warning("Recording rejected by operation coordinator (at capacity or conflicting operation)", 
                          category: .audio, context: context, error: nil)
            throw RecordingError.recordingFailed("Unable to start recording - system busy or conflicting operation")
        }
        
        logger.debug("Recording operation registered with ID: \(operationId)", category: .audio, context: context)
        
        do {
            // Check if already recording
            if let audioRepoImpl = audioRepository as? AudioRepositoryImpl {
                await MainActor.run {
                    guard !audioRepoImpl.isRecording else {
                        Task {
                            await operationCoordinator.failOperation(operationId, error: RecordingError.alreadyRecording)
                        }
                        return
                    }
                    
                    // Check permissions first
                    guard audioRepoImpl.hasMicrophonePermission else {
                        // Try to refresh permissions
                        audioRepoImpl.checkMicrophonePermissions()
                        Task {
                            await operationCoordinator.failOperation(operationId, error: RecordingError.permissionDenied)
                        }
                        return
                    }
                    
                    // Store memo ID for later use when recording completes
                    // TODO: Pass memoId to BackgroundAudioService
                    
                    // Start background recording synchronously
                    audioRepoImpl.startRecordingSync()
                    
                    logger.info("Background recording started successfully", category: .audio, context: context)
                }
            } else if let wrapper = audioRepository as? AudioRecordingServiceWrapper {
                // Use legacy AudioRecordingService
                let service = wrapper.service
                
                guard !service.isRecording else {
                    await operationCoordinator.failOperation(operationId, error: RecordingError.alreadyRecording)
                    throw RecordingError.alreadyRecording
                }
                
                guard service.hasPermission else {
                    await operationCoordinator.failOperation(operationId, error: RecordingError.permissionDenied)
                    throw RecordingError.permissionDenied
                }
                
                service.startRecording()
                logger.info("Legacy recording started successfully", category: .audio, context: context)
            } else {
                let error = RecordingError.recordingFailed("Audio repository does not support recording")
                await operationCoordinator.failOperation(operationId, error: error)
                throw error
            }
            
            return memoId
            
        } catch {
            // Ensure operation is failed if any error occurs
            await operationCoordinator.failOperation(operationId, error: error)
            throw error
        }
    }
}

// MARK: - Recording Errors
enum RecordingError: LocalizedError {
    case alreadyRecording
    case notRecording
    case permissionDenied
    case recordingFailed(String)
    case fileSystemError
    case audioSessionFailed(String)
    case backgroundTaskFailed
    case backgroundRecordingNotSupported
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording is currently in progress"
        case .permissionDenied:
            return "Microphone permission is required"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .fileSystemError:
            return "File system error occurred"
        case .audioSessionFailed(let message):
            return "Audio session configuration failed: \(message)"
        case .backgroundTaskFailed:
            return "Failed to start background task for recording"
        case .backgroundRecordingNotSupported:
            return "Background recording is not supported on this device"
        }
    }
}