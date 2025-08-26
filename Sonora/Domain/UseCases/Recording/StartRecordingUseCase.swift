import Foundation

/// Use case for starting audio recording
/// Encapsulates the business logic for initiating recording sessions with background support
protocol StartRecordingUseCaseProtocol {
    func execute() throws
}

final class StartRecordingUseCase: StartRecordingUseCaseProtocol {
    
    // MARK: - Dependencies
    private let audioRepository: AudioRepository
    
    // MARK: - Initialization
    init(audioRepository: AudioRepository) {
        self.audioRepository = audioRepository
    }
    
    // MARK: - Convenience Initializer (for backward compatibility)
    convenience init(audioRecordingService: AudioRecordingService) {
        // Create a wrapper that implements AudioRepository protocol
        // This is a temporary solution for backward compatibility
        self.init(audioRepository: AudioRecordingServiceWrapper(service: audioRecordingService))
    }
    
    // MARK: - Use Case Execution
    func execute() throws {
        print("🎤 StartRecordingUseCase: Starting recording")
        
        // Check if already recording
        if let audioRepoImpl = audioRepository as? AudioRepositoryImpl {
            Task { @MainActor in
                guard !audioRepoImpl.isRecording else {
                    print("❌ StartRecordingUseCase: Already recording")
                    return
                }
                
                // Check permissions first
                guard audioRepoImpl.hasMicrophonePermission else {
                    // Try to refresh permissions
                    audioRepoImpl.checkMicrophonePermissions()
                    print("❌ StartRecordingUseCase: Microphone permission denied")
                    return
                }
                
                // Start background recording synchronously
                audioRepoImpl.startRecordingSync()
            }
        } else if let wrapper = audioRepository as? AudioRecordingServiceWrapper {
            // Use legacy AudioRecordingService
            let service = wrapper.service
            
            guard !service.isRecording else {
                throw RecordingError.alreadyRecording
            }
            
            guard service.hasPermission else {
                throw RecordingError.permissionDenied
            }
            
            service.startRecording()
            print("🎤 StartRecordingUseCase: Recording started successfully (legacy)")
        } else {
            throw RecordingError.recordingFailed("Audio repository does not support recording")
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