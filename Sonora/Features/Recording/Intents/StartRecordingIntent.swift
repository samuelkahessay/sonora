//
//  StartRecordingIntent.swift
//  Sonora
//
//  Created for Action Button integration
//

import AppIntents
import Foundation

// MARK: - Start Recording Intent
// This intent can be triggered by:
// - iPhone Action Button
// - Siri voice commands ("Start recording in Sonora")
// - Shortcuts app
// - Automations
@available(iOS 16.0, *)
struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource { "Start Recording" }
    static var description: IntentDescription {
        IntentDescription("Starts recording a voice memo in Sonora")
    }

    // Run in background without opening the app for seamless Action Button experience
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Get dependencies from DI container
        let canStartRecordingUseCase = DIContainer.shared.canStartRecordingUseCase()
        let startRecordingUseCase = DIContainer.shared.startRecordingUseCase()
        let notificationService = DIContainer.shared.notificationService()

        do {
            // Pre-flight checks: verify quota and get allowed duration
            let allowedDuration: TimeInterval?
            do {
                allowedDuration = try await canStartRecordingUseCase.execute(service: TranscriptionServiceType.cloudAPI)
            } catch let error as RecordingQuotaError {
                // Handle quota errors
                switch error {
                case .limitReached(let remaining):
                    await notificationService.sendRecordingErrorNotification(
                        error: .quotaExceeded(remaining: remaining)
                    )
                    return .result()
                }
            }

            // Start recording with allowed duration cap
            let memoId = try await startRecordingUseCase.execute(capSeconds: allowedDuration)

            // Recording started successfully - silent success
            print("🎙️ StartRecordingIntent: Recording started successfully with memoId: \(memoId?.uuidString ?? "unknown")")
            return .result()

        } catch RecordingError.alreadyRecording {
            // Already recording - notify user
            await notificationService.sendRecordingErrorNotification(error: .alreadyRecording)
            return .result()

        } catch RecordingError.permissionDenied {
            // Microphone permission denied
            await notificationService.sendRecordingErrorNotification(error: .permissionDenied)
            return .result()

        } catch {
            // Generic system error
            await notificationService.sendRecordingErrorNotification(
                error: .systemError(error.localizedDescription)
            )
            return .result()
        }
    }
}
