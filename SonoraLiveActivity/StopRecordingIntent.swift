import AppIntents
import SwiftUI

// MARK: - Stop Recording Intent
// This intent is triggered by the "Stop" button on the Live Activity.
// It accesses the app's services to gracefully stop the background recording.
@available(iOS 17.0, *)
struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource { "Stop Recording" }
    static var description: IntentDescription { IntentDescription("Stops the current recording in Sonora") }

    // This intent should open the app and then perform the action.
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Since this intent opens the app (openAppWhenRun: true), we'll let the main app
        // handle the stop recording logic when it becomes active.
        // The Live Activity extension runs in a separate process and doesn't have
        // direct access to the main app's services.

        print("🎙️ StopRecordingIntent: Intent triggered - app will open and handle stop recording.")

        // Set a flag in shared UserDefaults to indicate that recording should be stopped
        // This will be checked by the main app when it becomes active
        let sharedDefaults = UserDefaults(suiteName: "group.sonora.shared") ?? UserDefaults.standard
        sharedDefaults.set(true, forKey: "shouldStopRecordingOnActivation")
        sharedDefaults.synchronize()

        // The app will be opened automatically and can check the flag to stop recording
        return .result()
    }
}
