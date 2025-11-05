import SwiftUI

struct AboutSupportLegalSectionView: View {
    @StateObject private var viewModel = AboutSupportLegalViewModel()

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Label("About & Support", systemImage: "info.circle")
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
                    sectionHeader("Important Notice")
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.semantic(.brandPrimary))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Not a Substitute for Professional Help")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.semantic(.textPrimary))

                            Text("Sonora is a thinking tool for verbal processors, not therapy or mental health treatment. If you're experiencing mental health concerns, please consult a licensed professional.")
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
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
