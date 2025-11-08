import SwiftUI

/// Placeholder shown while the dynamic prompt is loading.
struct PromptPlaceholderCard: View {
    @SwiftUI.Environment(\.colorScheme)
    private var colorScheme: ColorScheme

    var body: some View {
        Text("Loading your prompt…")
            .font(SonoraDesignSystem.Typography.insightSerif)
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .semantic(.textPrimary))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .redacted(reason: .placeholder)
            .accessibilityHidden(true)
    }
}
