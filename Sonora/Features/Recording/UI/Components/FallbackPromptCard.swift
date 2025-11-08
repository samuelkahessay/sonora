import SwiftUI

struct FallbackPromptCard: View {
    let onRefresh: () -> Void

    @SwiftUI.Environment(\.accessibilityReduceMotion)
    private var reduceMotion: Bool
    @SwiftUI.Environment(\.colorScheme)
    private var colorScheme: ColorScheme

    var body: some View {
        Text(DIContainer.shared.localizationProvider().localizedString("prompt.fallback.tap", locale: .current))
            .font(SonoraDesignSystem.Typography.insightSerif)
            .foregroundColor(colorScheme == .dark ? .white : .semantic(.textPrimary))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.9)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(
                Text(DIContainer.shared.localizationProvider().localizedString("prompt.fallback.tap", locale: .current))
            )
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale))
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.9), value: UUID())
    }
}
