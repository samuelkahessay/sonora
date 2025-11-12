//
//  SonoraAppShortcuts.swift
//  Sonora
//
//  App Shortcuts provider for discoverability in Shortcuts app, Siri, and Spotlight
//

import AppIntents

// MARK: - App Shortcuts Provider
// This makes our intents easily discoverable throughout iOS:
// - Shortcuts app gallery
// - Siri suggestions
// - Spotlight search
// - Action Button configuration
@available(iOS 16.0, *)
struct SonoraAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start recording in \(.applicationName)",
                "Record a memo in \(.applicationName)",
                "Start a recording in \(.applicationName)",
                "Record a voice memo in \(.applicationName)"
            ],
            shortTitle: "Start Recording",
            systemImageName: "mic.fill"
        )
    }
}
