import SwiftUI

struct FallbackPromptCard: View {
    let onRefresh: () -> Void

    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        Button(action: onRefresh) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "lightbulb")
                    .imageScale(.large)
                    .foregroundColor(.semantic(.textSecondary))
                Text(LocalizedStringKey("prompt.fallback.tap"))
                    .font(SonoraDesignSystem.Typography.insightSerif)
                    .foregroundColor(.semantic(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .dark ? Color.semantic(.bgSecondary) : Color.clarityWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.semantic(.separator).opacity(0.15), lineWidth: 1)
            )
            .cardShadow()
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(LocalizedStringKey("prompt.fallback.tap")))
        .accessibilityHint("Double tap to try another idea")
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale))
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.9), value: UUID())
    }
}
