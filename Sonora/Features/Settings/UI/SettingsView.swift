import SwiftUI

struct SettingsView: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if FeatureFlags.showOnboarding {
                        OnboardingSectionView()
                    }
                    if FeatureFlags.showLanguage {
                        LanguageSectionView()
                    }
                    // Simplified transcription section for beta
                    TranscriptionServiceSectionSimple()
                    if FeatureFlags.showAutoDetection {
                        AutoDetectionSectionView()
                    }
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
