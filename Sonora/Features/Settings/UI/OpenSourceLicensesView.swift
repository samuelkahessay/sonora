import SwiftUI

struct OpenSourceLicensesView: View {
    private let licenses = LicenseInfo.all

    var body: some View {
        NavigationStack {
            ScrollView {
                SettingsCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Label("Open Source Licenses", systemImage: "text.badge.checkmark")
                            .font(SonoraDesignSystem.Typography.headingSmall)
                            .accessibilityAddTraits(.isHeader)

                        VStack(spacing: 0) {
                            ForEach(licenses) { license in
                                NavigationLink(value: license) {
                                    HStack(spacing: Spacing.sm) {
                                        Image(systemName: "chevron.left.slash.chevron.right")
                                            .foregroundColor(.semantic(.brandPrimary))
                                            .frame(width: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(license.libraryName)
                                                .font(.subheadline)
                                                .foregroundColor(.semantic(.textPrimary))
                                            Text("\(license.licenseType) — \(license.copyright)")
                                                .font(.caption)
                                                .foregroundColor(.semantic(.textSecondary))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.semantic(.textTertiary))
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)

                                if license.id != licenses.last?.id {
                                    Divider().padding(.vertical, 8)
                                }
                            }
                        }

                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.semantic(.textSecondary))
                                .font(.footnote)
                            Text("This app uses open source software. Tap a library to view its license.")
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                        .padding(.top, Spacing.xs)
                    }
                }
                .padding(.horizontal)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.semantic(.bgPrimary).ignoresSafeArea())
            .navigationTitle("Licenses")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LicenseInfo.self) { license in
                LicenseDetailView(license: license)
            }
        }
    }
}
