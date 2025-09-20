import SwiftUI

struct AboutSupportLegalSectionView: View {
    @StateObject private var viewModel = AboutSupportLegalViewModel()

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Label("About, Support & Legal", systemImage: "info.circle")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    sectionHeader("About")
                    SettingsRow(icon: "microphone.fill", title: "Sonora", subtitle: "Version \(viewModel.appVersion)", trailingText: "Build \(viewModel.buildNumber)")
                        .accessibilityLabel("Sonora version \(viewModel.appVersion), build \(viewModel.buildNumber)")
                }

                Divider().background(Color.semantic(.separator))

                VStack(alignment: .leading, spacing: Spacing.md) {
                    sectionHeader("Support")
                    Button(action: viewModel.openSupport) {
                        SettingsRow(icon: "bubble.left.and.bubble.right", title: "Get Support", subtitle: "Help, guides, and feedback", trailingSystemImage: "arrow.up.right")
                    }
                    .buttonStyle(.plain)
                    #if DEBUG
                    NavigationLink(destination: DiagnosticsSectionView()) {
                        SettingsRow(icon: "waveform.path.ecg", title: "Diagnostics Dashboard", subtitle: "Debug build only", trailingSystemImage: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    #endif
                }

                Divider().background(Color.semantic(.separator))

                VStack(alignment: .leading, spacing: Spacing.md) {
                    sectionHeader("Privacy & Legal")
                    Button(action: viewModel.openPrivacyPolicy) {
                        SettingsRow(icon: "hand.raised", title: "Privacy Policy", subtitle: "How we protect your data", trailingSystemImage: "arrow.up.right")
                    }
                    .buttonStyle(.plain)

                    Button(action: viewModel.openTerms) {
                        SettingsRow(icon: "doc.text", title: "Terms of Service", subtitle: "Usage terms and conditions", trailingSystemImage: "arrow.up.right")
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.semantic(.textSecondary))
                            .font(.footnote)
                        Text("Transcription and analysis happen via Sonora's secure cloud services. Manage exports above when you need a copy.")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                    .padding(.top, Spacing.xs)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundColor(.semantic(.textSecondary))
            .accessibilityHidden(true)
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    var trailingSystemImage: String?
    var trailingText: String?

    init(icon: String, title: String, subtitle: String? = nil, trailingSystemImage: String? = nil, trailingText: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailingSystemImage = trailingSystemImage
        self.trailingText = trailingText
    }

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

            if let trailingText = trailingText {
                Text(trailingText)
                    .font(.caption2)
                    .foregroundColor(.semantic(.textTertiary))
            }

            if let systemName = trailingSystemImage {
                Image(systemName: systemName)
                    .font(.caption)
                    .foregroundColor(.semantic(systemName == "chevron.right" ? .textTertiary : .brandPrimary))
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

#if DEBUG
struct AboutSupportLegalSectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ScrollView {
                AboutSupportLegalSectionView()
                    .padding()
            }
        }
    }
}
#endif
