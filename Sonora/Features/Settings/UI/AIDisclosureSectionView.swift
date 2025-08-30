import SwiftUI

struct AIDisclosureSectionView: View {
    var body: some View {
        SettingsCard {
            Text("AI Features")
                .font(.headline)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Sonora uses AI to transcribe recordings and generate summaries, themes, and todos.")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                Text("AI-generated content may be inaccurate or incomplete. We label AI outputs and apply content safeguards to reduce harmful or deceptive content.")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                Text("Do not rely on AI outputs for medical, legal, or safety-critical decisions.")
                    .font(.footnote)
                    .foregroundColor(.semantic(.warning))
                    .padding(.top, 4)
            }
        }
    }
}
