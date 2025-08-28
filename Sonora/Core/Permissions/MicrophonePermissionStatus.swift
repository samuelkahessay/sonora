import Foundation
import AVFoundation

/// Comprehensive microphone permission status tracking
/// Provides clear differentiation between all possible permission states
public enum MicrophonePermissionStatus: String, CaseIterable, Equatable {
    case notDetermined = "not_determined"
    case granted = "granted"
    case denied = "denied"
    case restricted = "restricted"
    
    /// Human-readable display name for UI
    public var displayName: String {
        switch self {
        case .notDetermined:
            return "Permission Not Requested"
        case .granted:
            return "Permission Granted"
        case .denied:
            return "Permission Denied"
        case .restricted:
            return "Permission Restricted"
        }
    }
    
    /// User-friendly description of the status
    public var description: String {
        switch self {
        case .notDetermined:
            return "Microphone permission hasn't been requested yet"
        case .granted:
            return "Microphone access is allowed"
        case .denied:
            return "Microphone access was denied"
        case .restricted:
            return "Microphone access is restricted by device settings"
        }
    }
    
    /// Icon name for UI display
    public var iconName: String {
        switch self {
        case .notDetermined:
            return "mic.badge.plus"
        case .granted:
            return "mic.fill"
        case .denied:
            return "mic.slash.fill"
        case .restricted:
            return "lock.fill"
        }
    }
    
    /// Whether recording is allowed with this permission status
    public var allowsRecording: Bool {
        return self == .granted
    }
    
    /// Whether user can request permission (not permanently denied)
    public var canRequestPermission: Bool {
        return self == .notDetermined
    }
    
    /// Whether user needs to go to Settings to change permission
    public var requiresSettingsNavigation: Bool {
        return self == .denied
    }
    
    /// Convert from AVAudioSession.RecordPermission to our enum
    public static func from(avPermission: AVAudioSession.RecordPermission) -> MicrophonePermissionStatus {
        switch avPermission {
        case .undetermined:
            return .notDetermined
        case .granted:
            return .granted
        case .denied:
            return .denied
        @unknown default:
            return .denied // Safe fallback for future AVAudioSession cases
        }
    }
    
    /// Get current system permission status
    /// This is a synchronous read of the current state
    public static func current() -> MicrophonePermissionStatus {
        let avPermission = AVAudioSession.sharedInstance().recordPermission
        return from(avPermission: avPermission)
    }
}

/// Permission status change notification
public extension Notification.Name {
    static let microphonePermissionStatusChanged = Notification.Name("MicrophonePermissionStatusChanged")
}

/// Notification userInfo key for permission status
public extension MicrophonePermissionStatus {
    static let notificationUserInfoKey = "MicrophonePermissionStatus"
}

// MARK: - Permission Request API (Core layer)

/// Requests microphone permission using platform APIs and returns final status.
@MainActor
public func requestMicrophonePermission() async -> MicrophonePermissionStatus {
    return await withCheckedContinuation { continuation in
        let performRequest: (@escaping (Bool) -> Void) -> Void
        
        if #available(iOS 17.0, *) {
            performRequest = { completion in
                AVAudioApplication.requestRecordPermission(completionHandler: completion)
            }
        } else {
            performRequest = { completion in
                AVAudioSession.sharedInstance().requestRecordPermission(completion)
            }
        }
        
        performRequest { _ in
            let status = MicrophonePermissionStatus.current()
            continuation.resume(returning: status)
        }
    }
}
