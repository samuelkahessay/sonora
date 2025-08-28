import Foundation
import AVFoundation

/// Use case for requesting microphone permission
/// Encapsulates the business logic for handling microphone permissions with proper async support
protocol RequestMicrophonePermissionUseCaseProtocol {
    func execute() async -> MicrophonePermissionStatus
    func getCurrentStatus() -> MicrophonePermissionStatus
}

final class RequestMicrophonePermissionUseCase: RequestMicrophonePermissionUseCaseProtocol {
    
    // MARK: - Dependencies
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    init(logger: LoggerProtocol = Logger.shared) {
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
        return await withCheckedContinuation { continuation in
            let requestPermission: (@escaping (Bool) -> Void) -> Void
            
            // Use appropriate API based on iOS version
            if #available(iOS 17.0, *) {
                requestPermission = { completion in
                    AVAudioApplication.requestRecordPermission(completionHandler: completion)
                }
            } else {
                requestPermission = { completion in
                    AVAudioSession.sharedInstance().requestRecordPermission(completion)
                }
            }
            
            logger.debug("Requesting permission from system", category: .audio, context: LogContext())
            
            requestPermission { [weak self] granted in
                let finalStatus = MicrophonePermissionStatus.current()
                
                self?.logger.info("Permission request completed", 
                                category: .audio,
                                context: LogContext(additionalInfo: [
                                    "granted": granted,
                                    "final_status": finalStatus.rawValue
                                ]))
                
                // Post notification for UI updates
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .microphonePermissionStatusChanged,
                        object: nil,
                        userInfo: [MicrophonePermissionStatus.notificationUserInfoKey: finalStatus]
                    )
                }
                
                continuation.resume(returning: finalStatus)
            }
        }
    }
}

 
