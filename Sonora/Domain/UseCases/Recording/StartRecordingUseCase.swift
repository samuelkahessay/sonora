import Foundation

/// Use case for starting audio recording
/// Encapsulates the business logic for initiating recording sessions with background support
protocol StartRecordingUseCaseProtocol {
    func execute() async throws -> UUID?
}

final class StartRecordingUseCase: StartRecordingUseCaseProtocol {
    
    // MARK: - Dependencies
    private let audioRepository: any AudioRepository
    private let operationCoordinator: any OperationCoordinatorProtocol
    private let logger: any LoggerProtocol
    
    // MARK: - Initialization
    init(
        audioRepository: any AudioRepository,
        operationCoordinator: any OperationCoordinatorProtocol,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.audioRepository = audioRepository
        self.operationCoordinator = operationCoordinator
        self.logger = logger
    }
    
    
    
    // MARK: - Use Case Execution
    func execute() async throws -> UUID? {
        // Pre-checks on main actor (iOS requirement)
        try await MainActor.run {
            guard !audioRepository.isRecording else {
                throw RecordingError.alreadyRecording
            }
            guard audioRepository.hasMicrophonePermission else {
                audioRepository.checkMicrophonePermissions()
                throw RecordingError.permissionDenied
            }
        }

        // Start recording via repository; repository returns the actual memoId
        let memoId = try await audioRepository.startRecording()
        let context = LogContext(additionalInfo: ["memoId": memoId.uuidString])
        logger.info("Background recording started successfully", category: .audio, context: context)

        // Register the operation after successful start; rollback if registration fails
        if let operationId = await operationCoordinator.registerOperation(.recording(memoId: memoId)) {
            logger.debug("Recording operation registered with ID: \(operationId)", category: .audio, context: context)
            return memoId
        } else {
            await MainActor.run {
                self.audioRepository.stopRecording()
            }
            logger.warning("Recording rejected by operation coordinator (at capacity or conflicting operation)",
                           category: .audio, context: context, error: nil)
            throw RecordingError.recordingFailed("Unable to start recording - system busy or conflicting operation")
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
