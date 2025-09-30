import SwiftUI

struct SupportAboutSectionView: View {
    @SwiftUI.Environment(\.openURL)
    var openURL

    private var appVersion: String { BuildConfiguration.shared.appVersion }
    private var buildNumber: String { BuildConfiguration.shared.buildNumber }

    private let supportURLString = "https://samuelkahessay.github.io/sonora/support.html"

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Support & About", systemImage: "questionmark.circle")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityAddTraits(.isHeader)

                Button(action: { if let url = URL(string: supportURLString) { openURL(url) } }) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.semantic(.brandPrimary))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Get Support")
                                .font(.subheadline)
                                .foregroundColor(.semantic(.textPrimary))
                            Text("Help and feedback")
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.semantic(.textTertiary))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.vertical, 8)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sonora")
                            .font(.subheadline)
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                    Spacer()
                    Text("Build \(buildNumber)")
                        .font(.caption2)
                        .foregroundColor(.semantic(.textTertiary))
                }
            }
        }
    }
}
