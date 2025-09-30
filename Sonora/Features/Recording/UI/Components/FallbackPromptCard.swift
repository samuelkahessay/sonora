import SwiftUI

struct FallbackPromptCard: View {
    let onRefresh: () -> Void

    @SwiftUI.Environment(\.accessibilityReduceMotion)
    private var reduceMotion: Bool
    @SwiftUI.Environment(\.colorScheme)
    private var colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
                Image(systemName: "lightbulb")
                    .imageScale(.large)
                    .foregroundColor(colorScheme == .dark ? .white : .semantic(.textPrimary))
                Text(DIContainer.shared.localizationProvider().localizedString("prompt.fallback.tap", locale: .current))
                    .font(SonoraDesignSystem.Typography.insightSerif)
                    .foregroundColor(colorScheme == .dark ? .white : .semantic(.textPrimary))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityLabel(
            Text(DIContainer.shared.localizationProvider().localizedString("prompt.fallback.tap", locale: .current))
        )
        .accessibilityHint("Use the lightbulb button below to try another idea")
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale))
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.9), value: UUID())
    }
}
