import SwiftUI
import Combine

/// Combines daily usage visualization and transcription language into a single, concise card.
struct RecordingUsageSectionView: View {
    // Usage state
    @State private var usedSeconds: TimeInterval = 0
    @State private var cancellable: AnyCancellable?
    @State private var midnightTicker: AnyCancellable?

    private let totalDailyLimit: TimeInterval = 600 // 10 minutes for cloud

    // Language state
    @StateObject private var languageVM = TranscriptionLanguageSettingsViewModel()

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Recording & Usage", systemImage: "mic")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityAddTraits(.isHeader)

                // Usage
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    let remaining = max(0, Int(round(totalDailyLimit - usedSeconds)))
                    Text("\(formatReadable(seconds: remaining)) left today")
                        .font(.body)
                        .foregroundColor(.semantic(.textPrimary))

                    ProgressView(value: min(1.0, max(0.0, usedSeconds / totalDailyLimit)))
                        .tint(.semantic(.brandPrimary))

                    Text("Resets at midnight")
                        .font(.caption2)
                        .foregroundColor(.semantic(.textTertiary))
                }

                Divider().background(Color.semantic(.separator))

                // Language
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label("Transcription Language", systemImage: "globe")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.semantic(.textPrimary))
                        .accessibilityAddTraits(.isHeader)
                    Text("Used to improve cloud transcription accuracy.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))

                    Picker("Language", selection: $languageVM.selectedLanguageCode) {
                        ForEach(languageVM.languageOptions) { option in
                            Text(option.displayName).tag(option.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Preferred transcription language")
                }
            }
        }
        .onAppear {
            refreshUsage()
            subscribeToUsage()
            startMidnightWatcher()
        }
        .onDisappear {
            cancellable?.cancel(); cancellable = nil
            midnightTicker?.cancel(); midnightTicker = nil
        }
        .onChange(of: languageVM.selectedLanguageCode) { _, newValue in
            languageVM.updateSelectedLanguage(to: newValue)
        }
    }

    // MARK: - Usage helpers
    private func refreshUsage() {
        Task {
            let repo = DIContainer.shared.recordingUsageRepository()
            let today = Calendar.current.startOfDay(for: Date())
            let used = await repo.usage(for: today)
            await MainActor.run { usedSeconds = min(totalDailyLimit, used) }
        }
    }

    private func subscribeToUsage() {
        let repo = DIContainer.shared.recordingUsageRepository()
        cancellable = repo.todayUsagePublisher
            .receive(on: RunLoop.main)
            .sink { value in usedSeconds = min(totalDailyLimit, value) }
    }

    private func startMidnightWatcher() {
        midnightTicker = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let repo = DIContainer.shared.recordingUsageRepository()
                Task {
                    await repo.resetIfDayChanged(now: Date())
                    await MainActor.run { refreshUsage() }
                }
            }
    }

    private func formatReadable(seconds: Int) -> String {
        if seconds <= 0 { return "No time" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) \(hours == 1 ? "hour" : "hours")") }
        if minutes > 0 { parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")") }
        if secs > 0 && hours == 0 { parts.append("\(secs) \(secs == 1 ? "second" : "seconds")") }
        if parts.count > 1 { let last = parts.removeLast(); return parts.joined(separator: ", ") + " and " + last }
        return parts.first ?? "0 seconds"
    }
}

#Preview {
    RecordingUsageSectionView()
}

