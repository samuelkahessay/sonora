//
//  RecordingViewState.swift
//  Sonora
//
//  Consolidated state management for RecordingViewModel
//  Replaces 15 individual @Published properties with structured state
//

import Foundation
import SwiftUI

/// Consolidated state for RecordingView
/// Groups related properties into logical state structures for better maintainability
struct RecordingViewState: Equatable {

    // MARK: - Nested State Structures

    /// Recording session state
    struct RecordingState: Equatable {
        var isRecording: Bool = false
        var recordingTime: TimeInterval = 0
        var recordingStoppedAutomatically: Bool = false
        var autoStopMessage: String?
        var currentRecordingOperationId: UUID?

        /// Formatted recording time string
        var formattedRecordingTime: String {
            formatTime(recordingTime)
        }

        /// Recording button color based on state  
        var recordingButtonColor: Color {
            isRecording ? .semantic(.error) : .semantic(.brandPrimary)
        }

        /// Whether to show the recording indicator
        var shouldShowRecordingIndicator: Bool {
            isRecording
        }
    }

    /// Microphone permission state
    struct PermissionState: Equatable {
        var hasPermission: Bool = false
        var permissionStatus: MicrophonePermissionStatus = .notDetermined
        var isRequestingPermission: Bool = false

        /// Status text for the current permission state
        var statusText: String {
            if isRequestingPermission {
                return "Requesting Permission..."
            }

            switch permissionStatus {
            case .notDetermined:
                return "Microphone Access Needed"
            case .denied:
                return "Microphone Permission Denied"
            case .restricted:
                return "Microphone Access Restricted"
            case .granted:
                return "Ready to Record"
            }
        }
    }

    /// Auto-stop countdown state
    struct CountdownState: Equatable {
        var isInCountdown: Bool = false
        var remainingTime: TimeInterval = 0

        /// Formatted remaining time for countdown
        var formattedRemainingTime: String {
            "\(Int(ceil(remainingTime)))"
        }
    }

    /// Alert state for auto-stop notifications
    struct AlertState: Equatable {
        var showAutoStopAlert: Bool = false
    }

    /// Operation tracking state
    struct OperationState: Equatable {
        var recordingOperationStatus: DetailedOperationStatus?
        var queuePosition: Int?
        var systemMetrics: SystemOperationMetrics?

        // Custom Equatable since DetailedOperationStatus and SystemOperationMetrics may not be Equatable
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.queuePosition == rhs.queuePosition
            // Note: Simplified comparison for complex operation status types
        }
    }

    /// General UI state
    struct UIState: Equatable {
        var error: SonoraError?

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.error?.localizedDescription == rhs.error?.localizedDescription
        }
    }

    // MARK: - State Properties

    var recording = RecordingState()
    var permission = PermissionState()
    var countdown = CountdownState()
    var alert = AlertState()
    var operations = OperationState()
    var ui = UIState()

    /// Quota state (daily remaining and service type)
    struct QuotaState: Equatable {
        var service: TranscriptionServiceType = .cloudAPI
        /// Remaining daily seconds for Cloud service (nil when quota not enforced)
        var remainingDailySeconds: TimeInterval?

        var isLimited: Bool { remainingDailySeconds != nil }

        /// Button disabled if cloud and remaining <= 0
        var isRecordDisabledByQuota: Bool {
            if let rem = remainingDailySeconds { return rem <= 0 }
            return false
        }
    }

    var quota = QuotaState()

    // MARK: - Convenience Computed Properties

    /// Status text for the current recording state (comprehensive)
    var recordingStatusText: String {
        if permission.isRequestingPermission {
            return "Requesting Permission..."
        }

        switch permission.permissionStatus {
        case .notDetermined:
            return "Microphone Access Needed"
        case .denied:
            return "Microphone Permission Denied"
        case .restricted:
            return "Microphone Access Restricted"
        case .granted:
            if recording.isRecording {
                if countdown.isInCountdown {
                    return "Recording ends in"
                } else {
                    return "Recording..."
                }
            } else {
                return "Ready to Record"
            }
        }
    }

    /// Enhanced status text that includes operation status
    var enhancedStatusText: String {
        // Show operation status if available
        if let opStatus = operations.recordingOperationStatus {
            switch opStatus {
            case .queued:
                if let position = operations.queuePosition {
                    return "Queued (position \(position + 1))"
                }
                return "Queued for recording"
            case .waitingForResources:
                return "Waiting for system resources"
            case .waitingForConflictResolution:
                return "Waiting (another operation active)"
            case .processing(let progress):
                if let progress = progress {
                    return progress.currentStep
                }
                return "Processing recording"
            default:
                return "Recording in progress"
            }
        }

        return recordingStatusText
    }

    /// Whether the recording system is ready for user input
    var isReadyForRecording: Bool {
        permission.hasPermission &&
               !permission.isRequestingPermission &&
               operations.recordingOperationStatus == nil
    }

    /// Whether the record button should be disabled considering quota
    var isRecordButtonDisabled: Bool {
        if !isReadyForRecording { return true }
        return quota.isRecordDisabledByQuota
    }
}

// MARK: - State Mutation Helpers

extension RecordingViewState {

    /// Reset all state to initial values
    mutating func reset() {
        recording = RecordingState()
        permission = PermissionState()
        countdown = CountdownState()
        alert = AlertState()
        operations = OperationState()
        ui = UIState()
    }

    /// Update recording progress
    mutating func updateRecordingProgress(time: TimeInterval) {
        recording.recordingTime = time
    }

    /// Start countdown sequence
    mutating func startCountdown(remainingTime: TimeInterval) {
        countdown.isInCountdown = true
        countdown.remainingTime = remainingTime
    }

    /// Update countdown progress
    mutating func updateCountdown(remainingTime: TimeInterval) {
        countdown.remainingTime = remainingTime
        if remainingTime <= 0 {
            countdown.isInCountdown = false
        }
    }

    /// Set permission state
    mutating func updatePermission(status: MicrophonePermissionStatus, hasPermission: Bool) {
        permission.permissionStatus = status
        permission.hasPermission = hasPermission
        permission.isRequestingPermission = false
    }

    /// Set error state
    mutating func setError(_ error: SonoraError?) {
        ui.error = error
    }

    /// Clear error state
    mutating func clearError() {
        ui.error = nil
    }
}

// MARK: - Helper Functions

/// Format time interval as MM:SS string
private func formatTime(_ timeInterval: TimeInterval) -> String {
    let minutes = Int(timeInterval) / 60
    let seconds = Int(timeInterval) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
