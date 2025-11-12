import Combine
import SwiftUI

@MainActor
final class MonthlyUsageSectionViewModel: ObservableObject {
    // Dependencies
    private let usageRepo: any RecordingUsageRepository
    private let storeKit: any StoreKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // State
    @Published var monthSeconds: TimeInterval = 0
    @Published var isPro: Bool = false

    init(usageRepo: any RecordingUsageRepository, storeKit: any StoreKitServiceProtocol) {
        self.usageRepo = usageRepo
        self.storeKit = storeKit

        usageRepo.monthUsagePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] seconds in self?.monthSeconds = seconds }
            .store(in: &cancellables)

        storeKit.isProPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.isPro = value }
            .store(in: &cancellables)

        // Seed
        self.isPro = storeKit.isPro
    }

    convenience init() {
        let di = DIContainer.shared
        self.init(usageRepo: di.recordingUsageRepository(), storeKit: di.storeKitService())
    }

    var monthMinutesUsed: Int { Int((monthSeconds / 60.0).rounded(.toNearestOrEven)) }
    var monthCapMinutes: Int { 60 }
    var progress: Double { min(1.0, max(0.0, monthSeconds / 3_600.0)) }
}

struct MonthlyRecordingUsageSectionView: View {
    @StateObject private var vm = MonthlyUsageSectionViewModel()
    @State private var showPaywall = false

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Usage", systemImage: "timer")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityAddTraits(.isHeader)

                if vm.isPro {
                    Text("Unlimited recording")
                        .font(.body)
                        .foregroundColor(.semantic(.textPrimary))
                } else {
                    HStack(spacing: Spacing.md) {
                        MonthlyUsageProgressView(progress: vm.progress)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("This month • \(vm.monthMinutesUsed) of \(vm.monthCapMinutes) minutes used")
                                .font(.body)
                                .foregroundColor(.semantic(.textPrimary))
                            ProgressView(value: vm.progress)
                                .tint(.accentColor)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}

struct MonthlyUsageProgressView: View {
    let progress: Double // 0...1
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.semantic(.separator).opacity(0.3), lineWidth: 8)
                .frame(width: 44, height: 44)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.semantic(.fillSecondary), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Usage progress")
    }
}

struct UpgradeCallToActionView: View {
    @State private var showPaywall = false
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Upgrade to Pro", systemImage: "star.circle.fill")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                VStack(alignment: .leading, spacing: 6) {
                    bullet("Unlimited recording (remove 60 min/month limit)")
                    bullet("Full Distill insights (vs. Lite Distill on Free)")
                    bullet("Advanced analysis with patterns & connections across memos")
                    bullet("Calendar event & reminder creation from your voice")
                }
                Button("Upgrade to Pro") { showPaywall = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
            Text(text).foregroundColor(.semantic(.textPrimary)).font(.subheadline)
        }
    }
}

struct SubscriptionManagementView: View {
    @StateObject private var vm = MonthlyUsageSectionViewModel()
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Subscription", systemImage: "creditcard")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                HStack {
                    Button("Manage Subscription") { openManageSubscriptions() }
                        .buttonStyle(.bordered)
                    Button("Restore Purchases") { restore() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
    private func openManageSubscriptions() {
        #if canImport(UIKit)
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
        #endif
    }
    private func restore() {
        Task { @MainActor in
            _ = try? await DIContainer.shared.storeKitService().restorePurchases()
        }
    }
}
