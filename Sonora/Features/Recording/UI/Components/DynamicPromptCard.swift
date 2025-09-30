import SwiftUI

struct DynamicPromptCard: View {
    let prompt: InterpolatedPrompt
    let onRefresh: () -> Void

    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .imageScale(.large)
                .foregroundColor(colorScheme == .dark ? .white : .semantic(.textPrimary))
            Text(prompt.text)
                .font(SonoraDesignSystem.Typography.insightSerif)
                .foregroundColor(colorScheme == .dark ? .white : .semantic(.textPrimary))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
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
        .accessibilityLabel("Prompt: \(prompt.text)")
        .accessibilityHint("Use the lightbulb button below to get a new prompt")
        .transition(reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9), value: prompt.id)
    }
}
