import SwiftUI

struct SettingsView: View {

    var body: some View {
        LargeTitleNavigationContainer(title: "Settings") {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Current Usage at the very top
                    CurrentUsageSectionView()

                    // Data management (exports + delete)
                    DataManagementSectionView()

                    // About, support, and legal content
                    AboutSupportLegalSectionView()
                }
                .padding(.horizontal)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.semantic(.bgPrimary).ignoresSafeArea())
        }
    }
}

#Preview {
    SettingsView()
}
