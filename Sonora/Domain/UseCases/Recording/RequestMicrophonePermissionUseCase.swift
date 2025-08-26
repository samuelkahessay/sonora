import Foundation

/// Use case for requesting microphone permission
/// Encapsulates the business logic for handling microphone permissions
protocol RequestMicrophonePermissionUseCaseProtocol {
    func execute() -> Bool
}

final class RequestMicrophonePermissionUseCase: RequestMicrophonePermissionUseCaseProtocol {
    
    // MARK: - Dependencies
    private let audioRecordingService: AudioRecordingService
    
    // MARK: - Initialization
    init(audioRecordingService: AudioRecordingService) {
        self.audioRecordingService = audioRecordingService
    }
    
    // MARK: - Use Case Execution
    func execute() -> Bool {
        // Check current permission status first
        audioRecordingService.checkPermissions()
        
        // Return current permission status
        let hasPermission = audioRecordingService.hasPermission
        
        if hasPermission {
            print("🎤 RequestMicrophonePermissionUseCase: Permission already granted")
        } else {
            print("🎤 RequestMicrophonePermissionUseCase: Permission request initiated")
        }
        
        return hasPermission
    }
}