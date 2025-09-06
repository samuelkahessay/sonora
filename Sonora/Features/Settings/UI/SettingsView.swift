import SwiftUI

struct SettingsView: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    OnboardingSectionView()
                    LanguageSectionView()
                    WhisperKitSectionView()
                    AutoDetectionSectionView()
                LocalAISectionView()
                AIDisclosureSectionView()
                PrivacySectionView()
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
