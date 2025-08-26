import Foundation

/// Use case for requesting microphone permission
/// Encapsulates the business logic for handling microphone permissions with enhanced audio repository support
protocol RequestMicrophonePermissionUseCaseProtocol {
    func execute() -> Bool
}

final class RequestMicrophonePermissionUseCase: RequestMicrophonePermissionUseCaseProtocol {
    
    // MARK: - Dependencies
    private let audioRepository: AudioRepository
    
    // MARK: - Initialization
    init(audioRepository: AudioRepository) {
        self.audioRepository = audioRepository
    }
    
    // MARK: - Convenience Initializer (for backward compatibility)
    convenience init(audioRecordingService: AudioRecordingService) {
        // Create a wrapper that implements AudioRepository protocol
        self.init(audioRepository: AudioRecordingServiceWrapper(service: audioRecordingService))
    }
    
    // MARK: - Use Case Execution
    
    /// Synchronous permission check
    func execute() -> Bool {
        if let wrapper = audioRepository as? AudioRecordingServiceWrapper {
            // Use legacy AudioRecordingService - this is synchronous
            let service = wrapper.service
            service.checkPermissions()
            
            let hasPermission = service.hasPermission
            
            if hasPermission {
                print("🎤 RequestMicrophonePermissionUseCase: Permission already granted (legacy)")
            } else {
                print("🎤 RequestMicrophonePermissionUseCase: Permission request initiated (legacy)")
            }
            
            return hasPermission
        } else {
            // For AudioRepositoryImpl, we can't do synchronous permission checking
            // due to main actor isolation, so return current known state
            print("⚠️ RequestMicrophonePermissionUseCase: Using legacy service for permission checking")
            return false
        }
    }
}