import Foundation

/// Use case for requesting microphone permission
/// Encapsulates the business logic for handling microphone permissions with proper async support
protocol RequestMicrophonePermissionUseCaseProtocol: Sendable {
    func execute() async -> MicrophonePermissionStatus
    func getCurrentStatus() -> MicrophonePermissionStatus
}

final class RequestMicrophonePermissionUseCase: RequestMicrophonePermissionUseCaseProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    private let logger: any LoggerProtocol
    
    // MARK: - Initialization
    init(logger: any LoggerProtocol = Logger.shared) {
        self.logger = logger
    }
    
    // MARK: - Use Case Execution
    
    /// Asynchronously request microphone permission
    /// Returns the final permission status after user interaction
    func execute() async -> MicrophonePermissionStatus {
        let currentStatus = getCurrentStatus()
        
        logger.info("Requesting microphone permission", 
                   category: .audio, 
                   context: LogContext(additionalInfo: ["current_status": currentStatus.rawValue]))
        
        // If already granted, return immediately
        if currentStatus == .granted {
            logger.debug("Permission already granted", category: .audio, context: LogContext())
            return .granted
        }
        
        // If restricted, can't request permission
        if currentStatus == .restricted {
            logger.warning("Permission is restricted, cannot request", category: .audio, context: LogContext(), error: nil)
            return .restricted
        }
        
        // If denied, we can't re-request (user must go to Settings)
        if currentStatus == .denied {
            logger.warning("Permission previously denied, user must use Settings", category: .audio, context: LogContext(), error: nil)
            return .denied
        }
        
        // Request permission for .notDetermined state
        return await requestPermissionFromSystem()
    }
    
    /// Get current permission status without requesting
    /// This is a synchronous read of the current state
    func getCurrentStatus() -> MicrophonePermissionStatus {
        return MicrophonePermissionStatus.current()
    }
    
    // MARK: - Private Methods
    
    private func requestPermissionFromSystem() async -> MicrophonePermissionStatus {
        // Delegate platform-specific permission request to Core/Permissions
        let finalStatus = await requestMicrophonePermission()
        
        logger.info("Permission request completed",
                    category: .audio,
                    context: LogContext(additionalInfo: [
                        "final_status": finalStatus.rawValue
                    ]))
        
        // Publish type-safe event for UI updates on the main actor
        await MainActor.run {
            EventBus.shared.publish(.microphonePermissionStatusChanged(status: finalStatus))
        }
        
        return finalStatus
    }
}

 
