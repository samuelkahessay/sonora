import SwiftUI

struct DynamicPromptCard: View {
    let prompt: InterpolatedPrompt
    let onRefresh: () -> Void
    
    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        Button(action: onRefresh) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "sparkles")
                    .imageScale(.large)
                    .foregroundColor(.semantic(.textSecondary))
                Text(prompt.text)
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
        .accessibilityLabel("Prompt: \(prompt.text)")
        .accessibilityHint("Double tap to get a new prompt")
        .transition(reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9), value: prompt.id)
    }
}
