import SwiftUI

struct PrivacyLegalSectionView: View {
    @SwiftUI.Environment(\.openURL) private var openURL
    private let privacyURLString = "https://samuelkahessay.github.io/sonora/privacy-policy.html"
    private let termsURLString = "https://samuelkahessay.github.io/sonora/terms-of-service.html"

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Privacy & Legal", systemImage: "lock.shield")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 0) {
                    Button {
                        if let url = URL(string: privacyURLString) { openURL(url) }
                    } label: {
                        SettingsRowLink(icon: "hand.raised", title: "Privacy Policy", subtitle: "How we protect your data")
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.vertical, 8)

                    Button {
                        if let url = URL(string: termsURLString) { openURL(url) }
                    } label: {
                        SettingsRowLink(icon: "doc.text", title: "Terms of Service", subtitle: "Terms and conditions")
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.semantic(.textSecondary))
                        .font(.footnote)
                    Text("Transcription and analysis are processed via Sonora's secure cloud services; see our policies for details.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
                .padding(.top, Spacing.xs)
            }
        }
    }
}

private struct SettingsRowLink: View {
    let icon: String
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.semantic(.brandPrimary))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textPrimary))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.semantic(.textTertiary))
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
