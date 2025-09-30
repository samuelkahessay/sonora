import AVFAudio
import AVFoundation
import Foundation

/// Comprehensive microphone permission status tracking
/// Provides clear differentiation between all possible permission states
public enum MicrophonePermissionStatus: String, CaseIterable, Equatable, Sendable {
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
        self == .granted
    }

    /// Whether user can request permission (not permanently denied)
    public var canRequestPermission: Bool {
        self == .notDetermined
    }

    /// Whether user needs to go to Settings to change permission
    public var requiresSettingsNavigation: Bool {
        self == .denied
    }

    /// Convert from AVAudioSession.RecordPermission to our enum
    public static func from(avPermission: AVAudioSession.RecordPermission) -> Self {
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
    public static func current() -> Self {
        if #available(iOS 17.0, *) {
            // Prefer AVAudioApplication on iOS 17+
            switch AVAudioApplication.shared.recordPermission {
            case .undetermined:
                return .notDetermined
            case .granted:
                return .granted
            case .denied:
                return .denied
            @unknown default:
                return .denied
            }
        } else {
            let avPermission = AVAudioSession.sharedInstance().recordPermission
            return from(avPermission: avPermission)
        }
    }
}

// MARK: - Permission Request API (Core layer)

/// Requests microphone permission using platform APIs and returns final status.
@MainActor
public func requestMicrophonePermission() async -> MicrophonePermissionStatus {
    _ = await withCheckedContinuation { continuation in
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    return MicrophonePermissionStatus.current()
}
