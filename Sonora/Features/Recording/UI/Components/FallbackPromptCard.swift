import SwiftUI

struct FallbackPromptCard: View {
    let onRefresh: () -> Void

    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    var body: some View {
        Button(action: onRefresh) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "lightbulb")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey("prompt.fallback.tap"))
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
        .accessibilityLabel(Text(LocalizedStringKey("prompt.fallback.tap")))
        .accessibilityHint("Double tap to try another idea")
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale))
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.9), value: UUID())
    }
}
