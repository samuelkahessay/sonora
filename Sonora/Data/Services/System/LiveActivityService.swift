//
//  LiveActivityService.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-01-26.
//

import Foundation
import Combine
#if canImport(ActivityKit)
@preconcurrency import ActivityKit
#endif

// Protocol and supporting types are defined in Domain/Protocols/LiveActivityServiceProtocol.swift

// MARK: - ActivityKit-backed Implementation

@MainActor
final class LiveActivityService: LiveActivityServiceProtocol, ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published private(set) var isActivityActive: Bool = false
    @Published private(set) var currentActivityId: String? = nil
    
    // MARK: - Private Properties
    private let activityStateSubject = CurrentValueSubject<LiveActivityState, Never>(.inactive)
    private var cancellables = Set<AnyCancellable>()
    private var lastUpdateAt: Date = .distantPast
    private let minUpdateInterval: TimeInterval = 0.5 // 2 Hz max
    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private var lastContentState: SonoraLiveActivityAttributes.ContentState?
    #endif
    
    // MARK: - Protocol Properties
    var activityStatePublisher: AnyPublisher<LiveActivityState, Never> {
        activityStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init() {
        setupStateObservation()
        print("📱 LiveActivityService: Initialized (ActivityKit-capable)")
    }
    
    deinit {
        // cancellables will be automatically cleaned up
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
    
    // MARK: - Protocol Implementation
    
    func startRecordingActivity(memoTitle: String, startTime: Date) async throws {
        if isActivityActive {
            try await endCurrentActivity(dismissalPolicy: .immediate)
        }
        activityStateSubject.send(.starting)
        
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            let authInfo = ActivityAuthorizationInfo()
            guard authInfo.areActivitiesEnabled else {
                activityStateSubject.send(.error(.permissionDenied))
                throw LiveActivityError.permissionDenied
            }
            
            let attributes = SonoraLiveActivityAttributes(memoId: UUID().uuidString)
            let initialState = SonoraLiveActivityAttributes.ContentState(
                memoTitle: memoTitle,
                startTime: startTime,
                duration: 0,
                isCountdown: false,
                remainingTime: nil,
                emoji: "🎤"
            )
            do {
                let activity: Activity<SonoraLiveActivityAttributes>
                if #available(iOS 16.2, *) {
                    let content = ActivityContent(state: initialState, staleDate: nil)
                    activity = try Activity<SonoraLiveActivityAttributes>.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil
                    )
                } else {
                    activity = try Activity<SonoraLiveActivityAttributes>.request(
                        attributes: attributes,
                        contentState: initialState,
                        pushType: nil
                    )
                }
                self.lastContentState = initialState
                activityStateSubject.send(.active(id: activity.id))
            } catch {
                activityStateSubject.send(.error(.startFailed(error.localizedDescription)))
                throw LiveActivityError.startFailed(error.localizedDescription)
            }
        } else {
            activityStateSubject.send(.error(.notSupported))
            throw LiveActivityError.notSupported
        }
        #else
        activityStateSubject.send(.error(.notSupported))
        throw LiveActivityError.notSupported
        #endif
    }
    
    func updateActivity(duration: TimeInterval, isCountdown: Bool, remainingTime: TimeInterval?, level: Double?) async throws {
        guard isActivityActive, let activityId = currentActivityId else {
            throw LiveActivityError.notActive
        }
        // Simple throttle to avoid excessive updates
        let now = Date()
        if now.timeIntervalSince(lastUpdateAt) < minUpdateInterval {
            return
        }
        lastUpdateAt = now
        activityStateSubject.send(.updating)
        
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            // Locate the activity and update state
            let activities = Activity<SonoraLiveActivityAttributes>.activities
            guard let activity = activities.first(where: { $0.id == activityId }) else {
                activityStateSubject.send(.error(.notActive))
                throw LiveActivityError.notActive
            }
            let base = self.lastContentState ?? SonoraLiveActivityAttributes.ContentState(
                memoTitle: "Recording",
                startTime: Date(),
                duration: 0,
                isCountdown: false,
                remainingTime: nil,
                emoji: isCountdown ? "⏳" : "🎤",
                level: nil
            )
            let newState = SonoraLiveActivityAttributes.ContentState(
                memoTitle: base.memoTitle,
                startTime: base.startTime,
                duration: duration,
                isCountdown: isCountdown,
                remainingTime: remainingTime,
                emoji: isCountdown ? "⏳" : "🎤",
                level: level
            )
            if #available(iOS 16.2, *) {
                await activity.update(ActivityContent(state: newState, staleDate: nil))
            } else {
                await activity.update(using: newState)
            }
            self.lastContentState = newState
            activityStateSubject.send(.active(id: activityId))
        } else {
            activityStateSubject.send(.error(.notSupported))
            throw LiveActivityError.notSupported
        }
        #else
        activityStateSubject.send(.error(.notSupported))
        throw LiveActivityError.notSupported
        #endif
    }
    
    func endCurrentActivity(dismissalPolicy: ActivityDismissalPolicy = .afterDelay(4.0)) async throws {
        guard isActivityActive, let activityId = currentActivityId else { return }
        activityStateSubject.send(.ending)
        
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            let activities = Activity<SonoraLiveActivityAttributes>.activities
            guard let activity = activities.first(where: { $0.id == activityId }) else {
                activityStateSubject.send(.inactive)
                return
            }
            let policy: ActivityUIDismissalPolicy
            switch dismissalPolicy {
            case .immediate:
                policy = .immediate
            case .afterDelay(let seconds):
                policy = .after(Date().addingTimeInterval(seconds))
            case .userDismissal:
                policy = .default
            }
            if #available(iOS 16.2, *) {
                let finalState = self.lastContentState ?? SonoraLiveActivityAttributes.ContentState(
                    memoTitle: "Recording",
                    startTime: Date(),
                    duration: 0,
                    isCountdown: false,
                    remainingTime: nil,
                    emoji: "🎤",
                    level: nil
                )
                // Use Task to handle ActivityContent Sendable limitations
                await Task { 
                    let content = ActivityContent(state: finalState, staleDate: nil)
                    await activity.end(content, dismissalPolicy: policy)
                }.value
            } else {
                await activity.end(dismissalPolicy: policy)
            }
            activityStateSubject.send(.inactive)
            self.lastContentState = nil
        } else {
            activityStateSubject.send(.error(.notSupported))
            throw LiveActivityError.notSupported
        }
        #else
        activityStateSubject.send(.error(.notSupported))
        throw LiveActivityError.notSupported
        #endif
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
