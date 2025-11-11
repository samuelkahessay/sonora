import SwiftUI

/// Section view for displaying personal insight in Distill results
struct PersonalInsightSectionView: View {
    let insight: PersonalInsight

    @ScaledMetric private var headerSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "lightbulb.max")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Personal Insight")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Personal insight section")

            PersonalInsightCardView(insight: insight)
        }
    }
}

// MARK: - Preview

#Preview("Personal Insight") {
    PersonalInsightSectionView(
        insight: PersonalInsight(
            type: .wordPattern,
            observation: "I notice you used 'should' 4 times in 2 minutes—do you feel that pressure?",
            invitation: "What would happen if you replaced 'should' with 'could'?"
        )
    )
    .padding()
}
