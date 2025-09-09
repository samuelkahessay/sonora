import SwiftUI

struct LicenseDetailView: View {
    let license: LicenseInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SettingsCard {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(license.libraryName)
                            .font(SonoraDesignSystem.Typography.headingSmall)
                        Text("\(license.licenseType)")
                            .font(.subheadline)
                            .foregroundColor(.semantic(.textSecondary))
                        Text(license.copyright)
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                }

                SettingsCard {
                    Text(license.licenseText)
                        .font(.footnote.monospaced())
                        .foregroundColor(.semantic(.textPrimary))
                        .textSelection(.enabled)
                        .accessibilityLabel("\(license.libraryName) license text")
                        .padding(.top, Spacing.xs)
                }
            }
            .padding(.horizontal)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.semantic(.bgPrimary).ignoresSafeArea())
        .navigationTitle(license.libraryName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

