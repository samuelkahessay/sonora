import AppIntents

// MARK: - Stop Recording Intent (no-op helper)
// Note: The Live Activity uses a deep link (Link with sonora://stopRecording)
// to instruct the host app to stop recording. This intent is left minimal and
// avoids referencing app-only types from the extension.
@available(iOS 17.0, *)
struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource { "Stop Recording" }
    static var description = IntentDescription("Opens Sonora to manage recording")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        // The deep link button in the Live Activity drives the stop action.
        // Opening the app provides additional fallback UX.
        return .result()
    }
}
