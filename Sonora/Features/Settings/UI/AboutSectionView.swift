import SwiftUI

struct AboutSectionView: View {
    private var buildInfo: String {
        AppConfiguration.shared.buildInformation
    }

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("About & Support", systemImage: "info.circle")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(buildInfo)
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    AboutSectionView().padding()
}
