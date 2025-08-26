//
//  LiveActivityService.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-01-26.
//

import Foundation
import Combine

// MARK: - Live Activity Protocol

/// Protocol defining the interface for Live Activity management
/// This provides a clean abstraction for implementing Live Activities
/// that can show recording progress on the Lock Screen and Dynamic Island
protocol LiveActivityServiceProtocol {
    
    /// Current state of the Live Activity
    var isActivityActive: Bool { get }
    
    /// Current activity identifier (nil if no activity is active)
    var currentActivityId: String? { get }
    
    /// Publisher for activity state changes
    var activityStatePublisher: AnyPublisher<LiveActivityState, Never> { get }
    
    /// Starts a new recording Live Activity
    /// - Parameters:
    ///   - memoTitle: Title for the memo being recorded
    ///   - startTime: When the recording started
    /// - Throws: LiveActivityError if the activity cannot be started
    func startRecordingActivity(memoTitle: String, startTime: Date) async throws
    
    /// Updates the current Live Activity with new recording information
    /// - Parameters:
    ///   - duration: Current recording duration
    ///   - isCountdown: Whether the recording is in countdown mode
    ///   - remainingTime: Time remaining if in countdown
    /// - Throws: LiveActivityError if no activity is active or update fails
    func updateActivity(duration: TimeInterval, isCountdown: Bool, remainingTime: TimeInterval?) async throws
    
    /// Ends the current Live Activity
    /// - Parameter dismissalPolicy: How the activity should be dismissed
    /// - Throws: LiveActivityError if no activity is active
    func endCurrentActivity(dismissalPolicy: ActivityDismissalPolicy) async throws
    
    /// Ends any existing activity and starts a new one (single-owner pattern)
    /// - Parameters:
    ///   - memoTitle: Title for the new memo being recorded
    ///   - startTime: When the new recording started
    /// - Throws: LiveActivityError if the new activity cannot be started
    func restartActivity(memoTitle: String, startTime: Date) async throws
}

// MARK: - Supporting Types

/// Represents the current state of Live Activity management
enum LiveActivityState {
    case inactive
    case starting
    case active(id: String)
    case updating
    case ending
    case error(LiveActivityError)
}

/// Policy for how Live Activities should be dismissed
enum ActivityDismissalPolicy {
    case immediate          // Dismiss immediately
    case afterDelay(TimeInterval)  // Dismiss after specified seconds
    case userDismissal      // Let user dismiss manually
}

/// Errors that can occur during Live Activity operations
enum LiveActivityError: LocalizedError {
    case notSupported
    case alreadyActive
    case notActive
    case startFailed(String)
    case updateFailed(String)
    case endFailed(String)
    case permissionDenied
    case systemUnavailable
    
    var errorDescription: String? {
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

// MARK: - Stub Implementation

/// Stub implementation of LiveActivityService for preparation and testing
/// This implementation logs all operations without actually creating Live Activities
/// Will be replaced with real ActivityKit implementation later
final class LiveActivityService: LiveActivityServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isActivityActive: Bool = false
    @Published private(set) var currentActivityId: String? = nil
    
    // MARK: - Private Properties
    private let activityStateSubject = CurrentValueSubject<LiveActivityState, Never>(.inactive)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Protocol Properties
    var activityStatePublisher: AnyPublisher<LiveActivityState, Never> {
        activityStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init() {
        setupStateObservation()
        print("📱 LiveActivityService: Initialized (Stub Implementation)")
        print("📱 Note: This is a stub implementation that logs operations for preparation")
    }
    
    deinit {
        cancellables.removeAll()
        print("📱 LiveActivityService: Deinitialized")
    }
    
    // MARK: - Private Setup
    private func setupStateObservation() {
        activityStateSubject
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func handleStateChange(_ state: LiveActivityState) {
        DispatchQueue.main.async {
            switch state {
            case .inactive:
                self.isActivityActive = false
                self.currentActivityId = nil
            case .starting:
                break // Keep current state during transition
            case .active(let id):
                self.isActivityActive = true
                self.currentActivityId = id
            case .updating:
                break // Keep current state during update
            case .ending:
                break // Keep current state during transition
            case .error:
                self.isActivityActive = false
                self.currentActivityId = nil
            }
        }
    }
    
    // MARK: - Protocol Implementation
    
    func startRecordingActivity(memoTitle: String, startTime: Date) async throws {
        print("📱 LiveActivityService: Starting recording activity")
        print("   - Memo Title: '\(memoTitle)'")
        print("   - Start Time: \(formatTime(startTime))")
        
        // Single-owner pattern: end any existing activity first
        if isActivityActive {
            print("📱 LiveActivityService: Ending existing activity before starting new one")
            try await endCurrentActivity(dismissalPolicy: .immediate)
        }
        
        activityStateSubject.send(.starting)
        
        // Simulate async operation delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Generate unique activity ID
        let activityId = "recording_\(UUID().uuidString.prefix(8))"
        
        // Simulate successful start
        print("📱 LiveActivityService: ✅ Recording activity started successfully")
        print("   - Activity ID: \(activityId)")
        print("   - Will show: Recording '\(memoTitle)' started at \(formatTime(startTime))")
        
        activityStateSubject.send(.active(id: activityId))
    }
    
    func updateActivity(duration: TimeInterval, isCountdown: Bool, remainingTime: TimeInterval?) async throws {
        guard isActivityActive, let activityId = currentActivityId else {
            print("❌ LiveActivityService: Cannot update - no active activity")
            throw LiveActivityError.notActive
        }
        
        print("📱 LiveActivityService: Updating activity \(activityId)")
        print("   - Duration: \(formatDuration(duration))")
        print("   - Is Countdown: \(isCountdown)")
        if let remaining = remainingTime {
            print("   - Remaining Time: \(formatDuration(remaining))")
        }
        
        activityStateSubject.send(.updating)
        
        // Simulate async operation delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Simulate successful update
        print("📱 LiveActivityService: ✅ Activity updated successfully")
        if isCountdown, let remaining = remainingTime {
            print("   - Will show: Recording ending in \(Int(ceil(remaining))) seconds")
        } else {
            print("   - Will show: Recording for \(formatDuration(duration))")
        }
        
        activityStateSubject.send(.active(id: activityId))
    }
    
    func endCurrentActivity(dismissalPolicy: ActivityDismissalPolicy = .afterDelay(4.0)) async throws {
        guard isActivityActive, let activityId = currentActivityId else {
            print("📱 LiveActivityService: No active activity to end")
            return
        }
        
        print("📱 LiveActivityService: Ending activity \(activityId)")
        print("   - Dismissal Policy: \(dismissalPolicyDescription(dismissalPolicy))")
        
        activityStateSubject.send(.ending)
        
        // Simulate async operation delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Simulate successful end
        print("📱 LiveActivityService: ✅ Activity ended successfully")
        print("   - Activity will be dismissed: \(dismissalPolicyDescription(dismissalPolicy))")
        
        activityStateSubject.send(.inactive)
    }
    
    func restartActivity(memoTitle: String, startTime: Date) async throws {
        print("📱 LiveActivityService: Restarting activity (single-owner pattern)")
        
        // This method ensures single-owner pattern by always ending before starting
        if isActivityActive {
            try await endCurrentActivity(dismissalPolicy: .immediate)
        }
        
        try await startRecordingActivity(memoTitle: memoTitle, startTime: startTime)
        
        print("📱 LiveActivityService: ✅ Activity restarted successfully")
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func dismissalPolicyDescription(_ policy: ActivityDismissalPolicy) -> String {
        switch policy {
        case .immediate:
            return "immediately"
        case .afterDelay(let seconds):
            return "after \(seconds) seconds"
        case .userDismissal:
            return "when user dismisses"
        }
    }
}

// MARK: - Future ActivityKit Integration Notes

/*
 When implementing real ActivityKit integration, this service will:
 
 1. Import ActivityKit framework
 2. Define ActivityAttributes for the Sonora recording widget
 3. Replace stub methods with actual Activity.request() calls
 4. Handle ActivityKit permissions and availability
 5. Manage Activity tokens and state updates
 6. Support Dynamic Island and Lock Screen displays
 
 The protocol and error types are designed to support this future implementation
 without requiring changes to consuming code.
 
 Example future implementation outline:
 
 ```swift
 import ActivityKit
 
 struct SonoraRecordingAttributes: ActivityAttributes {
     public struct ContentState: Codable, Hashable {
         var memoTitle: String
         var startTime: Date
         var duration: TimeInterval
         var isCountdown: Bool
         var remainingTime: TimeInterval?
     }
     
     var memoId: String
 }
 
 // In startRecordingActivity:
 let activity = try Activity<SonoraRecordingAttributes>.request(
     attributes: attributes,
     contentState: contentState,
     pushType: nil
 )
 ```
 */
