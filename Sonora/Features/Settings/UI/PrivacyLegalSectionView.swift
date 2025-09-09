import SwiftUI

struct PrivacyLegalSectionView: View {
    @State private var showLicenses = false
    private let privacyURL = URL(string: "https://samuelkahessay.github.io/sonora/privacy-policy.html")!
    private let termsURL = URL(string: "https://samuelkahessay.github.io/sonora/terms-of-service.html")!

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Privacy & Legal", systemImage: "lock.shield")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 0) {
                    Link(destination: privacyURL) {
                        SettingsRowLink(icon: "hand.raised", title: "Privacy Policy", subtitle: "How we protect your data")
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.vertical, 8)

                    Link(destination: termsURL) {
                        SettingsRowLink(icon: "doc.text", title: "Terms of Service", subtitle: "Terms and conditions")
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.vertical, 8)

                    Button(action: { showLicenses = true }) {
                        SettingsRowLink(
                            icon: "text.badge.checkmark",
                            title: "Open Source Licenses",
                            subtitle: "Third‑party acknowledgments"
                        )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.semantic(.textSecondary))
                        .font(.footnote)
                    Text("Your data never leaves your device when using Local processing.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
                .padding(.top, Spacing.xs)
            }
        }
        .sheet(isPresented: $showLicenses) { OpenSourceLicensesView() }
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
