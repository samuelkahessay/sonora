import SwiftUI

struct LocalAISectionView: View {
    @StateObject private var appConfig = AppConfiguration.shared
    
    var body: some View {
        SettingsCard {
            Text("Local AI")
                .font(SonoraDesignSystem.Typography.headingSmall)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Toggle("Use Local Analysis", isOn: $appConfig.useLocalAnalysis)
                    .accessibilityLabel("Toggle local AI analysis")
                if appConfig.useLocalAnalysis {
                    Text("Analysis runs on your device using LLaMA 3.2. No data is sent to external servers.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                } else {
                    Text("Analysis uses cloud services. More accurate but requires internet connection.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
                NavigationLink(destination: ModelDownloadView()) {
                    HStack {
                        Label("Manage Model", systemImage: "square.and.arrow.down")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.semantic(.textTertiary))
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, Spacing.sm)
            }
        }
    }
}
