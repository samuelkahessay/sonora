import SwiftUI

struct DynamicPromptCard: View {
    let prompt: InterpolatedPrompt
    let onRefresh: () -> Void
    
    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    var body: some View {
        Button(action: onRefresh) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "sparkles")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                Text(prompt.text)
                    .font(SonoraDesignSystem.Typography.insightSerif)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .cardStyle()
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
