//
//  NotificationService.swift
//  Sonora
//
//  Created for Action Button integration
//

import Foundation
@preconcurrency import UserNotifications

// MARK: - Protocol

protocol NotificationServiceProtocol: Sendable {
    func requestPermission() async -> Bool
    func sendRecordingErrorNotification(error: RecordingStartError) async
}

// MARK: - Recording Error Types

enum RecordingStartError {
    case quotaExceeded(remaining: TimeInterval?)
    case permissionDenied
    case alreadyRecording
    case systemError(String)
}

// MARK: - Implementation

final class NotificationService: NotificationServiceProtocol {
    private let notificationCenter: UNUserNotificationCenter

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    func requestPermission() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func sendRecordingErrorNotification(error: RecordingStartError) async {
        // Ensure we have permission
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            return
        }

        let content = UNMutableNotificationContent()
        content.sound = .default

        switch error {
        case .quotaExceeded(let remaining):
            content.title = "Recording Quota Exceeded"
            if let remaining = remaining, remaining > 0 {
                let minutes = Int(remaining / 60)
                content.body = "You have \(minutes) minutes remaining this month. Consider upgrading for unlimited recording."
            } else {
                content.body = "You've reached your monthly recording limit. Your quota will reset next month."
            }

        case .permissionDenied:
            content.title = "Microphone Permission Required"
            content.body = "Please grant microphone access in Settings to record with Sonora."

        case .alreadyRecording:
            content.title = "Already Recording"
            content.body = "A recording is already in progress. Stop the current recording before starting a new one."

        case .systemError(let message):
            content.title = "Recording Error"
            content.body = message
        }

        let request = UNNotificationRequest(
            identifier: "sonora.recording.error.\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            // Silent failure - notification system issues shouldn't block the app
            print("Failed to send notification: \(error)")
        }
    }
}
