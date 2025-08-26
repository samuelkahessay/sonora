import Foundation

/// Use case for starting audio recording
/// Encapsulates the business logic for initiating recording sessions
protocol StartRecordingUseCaseProtocol {
    func execute() throws
}

final class StartRecordingUseCase: StartRecordingUseCaseProtocol {
    
    // MARK: - Dependencies
    private let audioRecordingService: AudioRecordingService
    
    // MARK: - Initialization
    init(audioRecordingService: AudioRecordingService) {
        self.audioRecordingService = audioRecordingService
    }
    
    // MARK: - Use Case Execution
    func execute() throws {
        // Check if already recording
        guard !audioRecordingService.isRecording else {
            throw RecordingError.alreadyRecording
        }
        
        // Check permissions
        guard audioRecordingService.hasPermission else {
            throw RecordingError.permissionDenied
        }
        
        // Start recording
        audioRecordingService.startRecording()
        
        print("🎤 StartRecordingUseCase: Recording started successfully")
    }
}

// MARK: - Recording Errors
enum RecordingError: LocalizedError {
    case alreadyRecording
    case notRecording
    case permissionDenied
    case recordingFailed(String)
    case fileSystemError
    
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
        }
    }
}