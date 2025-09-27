import SwiftUI

struct SettingsView: View {

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Usage (monthly) — visible to all users
                    MonthlyRecordingUsageSectionView()

                    // Upgrade/Manage sections depending on entitlement
                    if DIContainer.shared.storeKitService().isPro {
                        SubscriptionManagementView()
                    } else {
                        UpgradeCallToActionView()
                    }
                    // Personalization (display name)
                    PersonalizationSectionView()

                    // Transcription language settings
                    // (Legacy usage meter removed in favor of monthly cap UI above)
                    TranscriptionLanguageSectionView()

                    // Non-destructive exports
                    ExportDataSectionView()

                    // About & Support (version/build, help, diagnostics)
                    AboutSupportLegalSectionView()

                    // Privacy & Legal (policies + disclaimer)
                    PrivacyLegalSectionView()

                    // Destructive actions clearly separated at bottom
                    DangerZoneSectionView()
                }
                .padding(.horizontal)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
            .background(Color.semantic(.bgPrimary).ignoresSafeArea())
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    SettingsView()
}
