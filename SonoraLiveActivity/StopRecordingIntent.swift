import AppIntents

// MARK: - Stop Recording Intent
// Opens the host app with a deep link so it can stop the current recording
// and dismiss any active Live Activity.
@available(iOS 17.0, *)
struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource { "Stop Recording" }
    static var description = IntentDescription("Stops the current recording in Sonora")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & OpensIntent {
        let url = URL(string: "sonora://stopRecording")!
        return .openApp(url)
    }
}
