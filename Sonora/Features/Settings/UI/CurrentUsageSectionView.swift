import SwiftUI
import Combine

struct CurrentUsageSectionView: View {
    @State private var usedSeconds: TimeInterval = 0
    @State private var remainingSeconds: TimeInterval? = nil
    @State private var service: TranscriptionServiceType = .cloudAPI
    @State private var cancellable: AnyCancellable?
    @State private var midnightTicker: AnyCancellable?

    @StateObject private var downloadManager = DIContainer.shared.modelDownloadManager()

    private let totalDailyLimit: TimeInterval = 600 // 10 minutes for cloud

    var body: some View {
        SettingsCard {
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

            VStack(alignment: .leading, spacing: Spacing.xs) {
                if service == .localWhisperKit {
                    Text("Unlimited (Local)")
                        .font(.body)
                        .foregroundColor(.semantic(.textPrimary))
                } else {
                    // Cloud: show remaining and used
                    let remaining = max(0, Int(round(remainingSeconds ?? max(0, totalDailyLimit - usedSeconds))))
                    let used = max(0, Int(round(usedSeconds)))
                    Text("Remaining Today: \(format(seconds: remaining)) (Cloud)")
                        .font(.body)
                        .foregroundColor(.semantic(.textPrimary))
                    Text("Used: \(format(seconds: used)) of \(format(seconds: Int(totalDailyLimit)))")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                        .padding(.top, 2)

                    // Progress towards daily limit
                    ProgressView(value: min(1.0, max(0.0, usedSeconds / totalDailyLimit)))
                        .tint(.semantic(.brandPrimary))
                        .padding(.top, Spacing.sm)

                    // Reset hint
                    Text("Resets at midnight")
                        .font(.caption2)
                        .foregroundColor(.semantic(.textTertiary))
                }
            }
        }
        .onAppear {
            refreshServiceAndUsage()
            subscribeToUsage()
            startMidnightWatcher()
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
            midnightTicker?.cancel()
            midnightTicker = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshServiceAndUsage()
        }
    }

    private func refreshServiceAndUsage() {
        // Determine effective service
        service = UserDefaults.standard.getEffectiveTranscriptionService(downloadManager: downloadManager)
        // Seed usedSeconds via repository query
        Task {
            let repo = DIContainer.shared.recordingUsageRepository()
            let today = Calendar.current.startOfDay(for: Date())
            let used = await repo.usage(for: today)
            await MainActor.run {
                usedSeconds = used
                if service == .cloudAPI {
                    remainingSeconds = max(0, totalDailyLimit - used)
                } else {
                    remainingSeconds = nil
                }
            }
        }
    }

    private func subscribeToUsage() {
        let repo = DIContainer.shared.recordingUsageRepository()
        cancellable = repo.todayUsagePublisher
            .receive(on: RunLoop.main)
            .sink { value in
                usedSeconds = value
                if service == .cloudAPI {
                    remainingSeconds = max(0, totalDailyLimit - value)
                } else {
                    remainingSeconds = nil
                }
            }
    }

    private func startMidnightWatcher() {
        // Poll once a minute to detect day change and refresh/reset usage view
        midnightTicker = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let repo = DIContainer.shared.recordingUsageRepository()
                Task {
                    await repo.resetIfDayChanged(now: Date())
                    await MainActor.run {
                        refreshServiceAndUsage()
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
