import SwiftUI

struct SettingsView: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    if FeatureFlags.useConsolidatedSettings {
                        // Section 1: Processing & Recording
                        ProcessingOptionsSection()

                        // Section 2: Data & Privacy (existing view already includes export/delete + links)
                        PrivacySectionView()

                        // Section 3: About & Support (lightweight version info)
                        AboutSectionView()
                    } else {
                        if FeatureFlags.showOnboarding { OnboardingSectionView() }
                        if FeatureFlags.showLanguage { LanguageSectionView() }
                        TranscriptionServiceSectionSimple()
                        if FeatureFlags.showAutoDetection { AutoDetectionSectionView() }
                        LocalAISectionView()
                        AIDisclosureSectionView()
                        PrivacySectionView()
                    }
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
