import Foundation
import Combine

/// Protocol defining the interface for Live Activity management
/// Abstraction for ActivityKit-backed Live Activities without coupling Domain to ActivityKit.
@MainActor
public protocol LiveActivityServiceProtocol {
    // Current state
    var isActivityActive: Bool { get }
    var currentActivityId: String? { get }
    var activityStatePublisher: AnyPublisher<LiveActivityState, Never> { get }

    // Lifecycle
    func startRecordingActivity(memoTitle: String, startTime: Date) async throws
    func updateActivity(duration: TimeInterval, isCountdown: Bool, remainingTime: TimeInterval?) async throws
    func endCurrentActivity(dismissalPolicy: ActivityDismissalPolicy) async throws
    func restartActivity(memoTitle: String, startTime: Date) async throws
}

/// Represents the current state of Live Activity management
public enum LiveActivityState: Sendable {
    case inactive
    case starting
    case active(id: String)
    case updating
    case ending
    case error(LiveActivityError)
}

/// Policy for how Live Activities should be dismissed
public enum ActivityDismissalPolicy: Sendable {
    case immediate                // Dismiss immediately
    case afterDelay(TimeInterval) // Dismiss after specified seconds
    case userDismissal            // Let user dismiss manually
}

/// Errors that can occur during Live Activity operations
public enum LiveActivityError: LocalizedError, Sendable {
    case notSupported
    case alreadyActive
    case notActive
    case startFailed(String)
    case updateFailed(String)
    case endFailed(String)
    case permissionDenied
    case systemUnavailable

    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Live Activities are not supported on this device or iOS version"
        case .alreadyActive:
            return "A Live Activity is already active"
        case .notActive:
            return "No Live Activity is currently active"
        case .startFailed(let message):
            return "Failed to start Live Activity: \(message)"
        case .updateFailed(let message):
            return "Failed to update Live Activity: \(message)"
        case .endFailed(let message):
            return "Failed to end Live Activity: \(message)"
        case .permissionDenied:
            return "Live Activity permission denied"
        case .systemUnavailable:
            return "Live Activity system is currently unavailable"
        }
    }
}

