import SwiftUI

struct DynamicPromptCard: View {
    let prompt: InterpolatedPrompt
    let onRefresh: () -> Void

    @SwiftUI.Environment(\.accessibilityReduceMotion)
    private var reduceMotion: Bool
    @SwiftUI.Environment(\.colorScheme)
    private var colorScheme: ColorScheme

    var body: some View {
        Text(prompt.text)
            .font(SonoraDesignSystem.Typography.insightSerif)
            .foregroundColor(colorScheme == .dark ? .white : .semantic(.textPrimary))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.9)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.opacity)
            .accessibilityLabel("Prompt: \(prompt.text)")
            .transition(reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9), value: prompt.id)
    }
}
