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

struct SettingsCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        SettingsCard { content }
    }
}

extension View {
    func settingsCard() -> some View { self.modifier(SettingsCardModifier()) }
}
