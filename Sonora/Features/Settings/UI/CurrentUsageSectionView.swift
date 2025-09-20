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
                let used = max(0, Int(round(usedSeconds)))

                Text("Remaining Today: \(format(seconds: remaining)) (Cloud)")
                    .font(.body)
                    .foregroundColor(.semantic(.textPrimary))
                Text("Used: \(format(seconds: used)) of \(format(seconds: Int(totalDailyLimit)))")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                    .padding(.top, 2)

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
}

#Preview {
    CurrentUsageSectionView()
}
