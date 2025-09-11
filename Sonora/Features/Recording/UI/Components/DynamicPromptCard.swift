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
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.15))
            )
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
