import SwiftUI

struct SettingsCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            content()
        }
        // Ensure all cards take the full available width inside SettingsView's padded ScrollView
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.semantic(.bgSecondary))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.semantic(.separator).opacity(0.45), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// removed unused SettingsCardModifier and View.settingsCard() helper
