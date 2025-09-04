import AppIntents

// MARK: - Stop Recording Intent (no-op helper)
// Note: The Live Activity uses a deep link (Link with sonora://stopRecording)
// to instruct the host app to stop recording. This intent is left minimal and
// avoids referencing app-only types from the extension.
@available(iOS 17.0, *)
struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource { "Stop Recording" }
    static var description: IntentDescription { IntentDescription("Stops the current recording in Sonora") }
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        // Opening the app is handled by openAppWhenRun.
        // The deep link for stopping is driven by the Link in the widget UI.
        return .result()
    }
}
