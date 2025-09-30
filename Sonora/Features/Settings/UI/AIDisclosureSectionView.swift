import SwiftUI

struct AIDisclosureSectionView: View {
    var body: some View {
        SettingsCard {
            Text("AI Features")
                .font(SonoraDesignSystem.Typography.headingSmall)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Sonora uses AI to transcribe recordings and generate summaries, themes, and todos.")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                    .accessibilityLabel("Sonora uses artificial intelligence to transcribe your recordings and generate summaries, themes, and to-do lists.")

                Text("AI-generated content may be inaccurate or incomplete. We label AI outputs and apply content safeguards to reduce harmful or deceptive content.")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                    .accessibilityLabel("AI-generated content may be inaccurate or incomplete. We clearly label AI outputs and apply content safeguards to reduce harmful or deceptive content.")

                Text("Do not rely on AI outputs for medical, legal, or safety-critical decisions.")
                    .font(.footnote)
                    .foregroundColor(.semantic(.warning))
                    .padding(.top, 4)
                    .accessibilityLabel("Important warning: Do not rely on AI outputs for medical, legal, or safety-critical decisions.")
                    .accessibilityAddTraits(.isStaticText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("AI Features disclosure. Sonora uses artificial intelligence to transcribe recordings and generate summaries, themes, and to-do lists. AI-generated content may be inaccurate or incomplete. We clearly label AI outputs and apply content safeguards to reduce harmful content. Important warning: Do not rely on AI outputs for medical, legal, or safety-critical decisions.")
        }
    }
}
