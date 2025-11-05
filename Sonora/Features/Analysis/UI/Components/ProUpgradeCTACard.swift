import SwiftUI

/// Pro upgrade CTA card shown in Lite Distill results
/// Positioned after Personal Insight to capitalize on user engagement
/// Design matches PersonalInsightCardView pattern for visual consistency
struct ProUpgradeCTACard: View {
    @State private var showPaywall = false

    @ScaledMetric private var cardPadding: CGFloat = 16
    @ScaledMetric private var contentSpacing: CGFloat = 12
    @ScaledMetric private var headerSpacing: CGFloat = 8
    @ScaledMetric private var iconSize: CGFloat = 20
    @ScaledMetric private var crownSize: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            // Header with crown icon
            HStack(spacing: headerSpacing) {
                Image(systemName: "crown.fill")
                    .font(.system(size: crownSize))
                    .foregroundColor(.semantic(.brandPrimary))
                    .accessibilityHidden(true)

                Text("Unlock Deeper Analysis")
                    .font(SonoraDesignSystem.Typography.cardTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.brandPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Unlock deeper analysis with Pro")

            // Description
            Text("Get advanced insights that connect patterns across your voice journal")
                .font(SonoraDesignSystem.Typography.cardBody)
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 4)

            // Pro Features
            VStack(alignment: .leading, spacing: 10) {
                benefitRow(icon: "brain.head.profile", text: "Thinking Patterns")
                benefitRow(icon: "link.circle", text: "Cross-memo Insights")
                benefitRow(icon: "book.closed", text: "Philosophical Wisdom")
                benefitRow(icon: "heart.circle", text: "Values Recognition")
            }
            .padding(.bottom, 4)

            // Primary CTA Button
            Button(action: {
                HapticManager.shared.playLightImpact()
                showPaywall = true
            }) {
                HStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Upgrade to Pro")
                        .font(.body)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Color.semantic(.brandPrimary))
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: Color.semantic(.brandPrimary).opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Upgrade to Sonora Pro")
        }
        .padding(cardPadding)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.semantic(.brandPrimary).opacity(0.08),
                    Color.semantic(.brandPrimary).opacity(0.03)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: SonoraDesignSystem.Spacing.cardRadius)
                .stroke(Color.semantic(.brandPrimary).opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Helpers

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundColor(.semantic(.brandPrimary))
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)

            Text(text)
                .font(.callout)
                .foregroundColor(.semantic(.textPrimary))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pro feature: \(text)")
    }
}

// MARK: - Preview

#Preview("Pro Upgrade CTA Card") {
    ProUpgradeCTACard()
        .padding()
        .background(Color.semantic(.bgPrimary))
}
