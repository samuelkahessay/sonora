import SwiftUI

/// Processing settings now simply communicate that transcription and analysis run in the cloud.
struct ProcessingOptionsSection: View {
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    Label("Processing", systemImage: "brain")
                        .font(SonoraDesignSystem.Typography.headingSmall)
                    Spacer()
                }

                Text("Transcription and analysis run on Sonora's secure cloud services for the best accuracy and reliability.")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
