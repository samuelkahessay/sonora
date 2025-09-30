import SwiftUI

/// Placeholder card shown while the dynamic prompt is loading.
/// Matches the prompt card’s shape, alignment, and background to avoid flicker.
struct PromptPlaceholderCard: View {
    @SwiftUI.Environment(\.colorScheme)
    private var colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .imageScale(.large)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .semantic(.textPrimary).opacity(0.6))

            Text("Loading your prompt…")
                .font(SonoraDesignSystem.Typography.insightSerif)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .semantic(.textPrimary))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .redacted(reason: .placeholder)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.semantic(.bgTertiary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.semantic(.separator).opacity(0.15), lineWidth: 1)
        )
        .cardShadow()
        .accessibilityHidden(true)
    }
}
