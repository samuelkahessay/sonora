import SwiftUI

struct SettingsView: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Current Usage at the very top
                    CurrentUsageSectionView()
                    // Section 1: Processing & Recording
                    ProcessingOptionsSection()

                    // Section 2: Data Management (exports + delete)
                    DataManagementSectionView()

                    // Section 3: Privacy & Legal (policy + terms)
                    PrivacyLegalSectionView()

                    // Section 4: Support & About
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
