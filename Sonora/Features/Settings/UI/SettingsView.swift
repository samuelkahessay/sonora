import SwiftUI

struct SettingsView: View {

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Personalization (display name)
                    PersonalizationSectionView()

                    // Consolidated Recording & Usage (quota + language)
                    RecordingUsageSectionView()

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
