import SwiftUI

struct SettingsView: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Current Usage at the very top
                    CurrentUsageSectionView()

                    // Data management (exports + delete)
                    DataManagementSectionView()

                    // Privacy & Legal (policy + terms)
                    PrivacyLegalSectionView()

                    // Support & About
                    SupportAboutSectionView()
                    #if DEBUG
                    DiagnosticsSectionView()
                    DebugSectionView()
                    #endif
                }
                .padding(.horizontal)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.semantic(.bgPrimary).ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView()
}
