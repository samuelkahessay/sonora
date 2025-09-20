import SwiftUI
import Combine

struct CurrentUsageSectionView: View {
    @State private var usedSeconds: TimeInterval = 0
    @State private var cancellable: AnyCancellable?
    @State private var midnightTicker: AnyCancellable?

    private let totalDailyLimit: TimeInterval = 600 // 10 minutes for cloud

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.title3)
                    Text("Current Usage")
                        .font(SonoraDesignSystem.Typography.headingSmall)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Current Usage")
                .accessibilityAddTraits(.isHeader)

                let remaining = max(0, Int(round(totalDailyLimit - usedSeconds)))

                Text("\(formatReadable(seconds: remaining)) left today")
                    .font(.body)
                    .foregroundColor(.semantic(.textPrimary))

                ProgressView(value: min(1.0, max(0.0, usedSeconds / totalDailyLimit)))
                    .tint(.semantic(.brandPrimary))
                    .padding(.top, Spacing.sm)

                Text("Resets at midnight")
                    .font(.caption2)
                    .foregroundColor(.semantic(.textTertiary))
            }
        }
        .onAppear {
            refreshUsage()
            subscribeToUsage()
            startMidnightWatcher()
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
            midnightTicker?.cancel()
            midnightTicker = nil
        }
    }

    private func refreshUsage() {
        Task {
            let repo = DIContainer.shared.recordingUsageRepository()
            let today = Calendar.current.startOfDay(for: Date())
            let used = await repo.usage(for: today)
            await MainActor.run {
                usedSeconds = min(totalDailyLimit, used)
            }
        }
    }

    private func subscribeToUsage() {
        let repo = DIContainer.shared.recordingUsageRepository()
        cancellable = repo.todayUsagePublisher
            .receive(on: RunLoop.main)
            .sink { value in
                usedSeconds = min(totalDailyLimit, value)
            }
    }

    private func startMidnightWatcher() {
        midnightTicker = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let repo = DIContainer.shared.recordingUsageRepository()
                Task {
                    await repo.resetIfDayChanged(now: Date())
                    await MainActor.run {
                        refreshUsage()
                    }
                }
            }
    }

    private func format(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatReadable(seconds: Int) -> String {
        if seconds <= 0 {
            return "No time"
        }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        var components: [String] = []

        if hours > 0 {
            components.append("\(hours) \(hours == 1 ? "hour" : "hours")")
        }

        if minutes > 0 {
            components.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")")
        }

        if remainingSeconds > 0 && hours == 0 {
            components.append("\(remainingSeconds) \(remainingSeconds == 1 ? "second" : "seconds")")
        }

        if components.isEmpty, remainingSeconds > 0 {
            components.append("\(remainingSeconds) \(remainingSeconds == 1 ? "second" : "seconds")")
        }

        if components.count > 1 {
            let last = components.removeLast()
            return components.joined(separator: ", ") + " and " + last
        }

        return components.first ?? "0 seconds"
    }
}

#Preview {
    CurrentUsageSectionView()
}
