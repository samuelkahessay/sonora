import SwiftUI

/// Displays a personal insight from Lite Distill analysis (free tier)
/// Creates the "aha moment" with type-specific visualization
internal struct PersonalInsightCardView: View {
    let insight: PersonalInsight

    @ScaledMetric private var cardPadding: CGFloat = 16
    @ScaledMetric private var contentSpacing: CGFloat = 12
    @ScaledMetric private var headerSpacing: CGFloat = 8
    @ScaledMetric private var iconSize: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            // Header with icon and type
            HStack(spacing: headerSpacing) {
                Image(systemName: insight.type.iconName)
                    .font(.system(size: iconSize))
                    .foregroundColor(colorForType(insight.type))
                    .accessibilityHidden(true)

                Text(insight.type.displayName)
                    .font(SonoraDesignSystem.Typography.cardTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(colorForType(insight.type))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(insight.type.displayName) insight")

            // Observation (main content)
            Text(insight.observation)
                .font(SonoraDesignSystem.Typography.cardBody)
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .accessibilityLabel("Observation: \(insight.observation)")

            // Optional invitation (Socratic question)
            if let invitation = insight.invitation, !invitation.isEmpty {
                Text(invitation)
                    .font(SonoraDesignSystem.Typography.cardBody)
                    .fontWeight(.medium)
                    .foregroundColor(.semantic(.textSecondary))
                    .italic()
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 4)
                    .accessibilityLabel("Question: \(invitation)")
            }
        }
        .padding(cardPadding)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    colorForType(insight.type).opacity(0.08),
                    colorForType(insight.type).opacity(0.03)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: SonoraDesignSystem.Spacing.cardRadius)
                .stroke(colorForType(insight.type).opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    private func colorForType(_ type: PersonalInsight.InsightType) -> Color {
        switch type.colorHint {
        case "pink":
            return .pink
        case "blue":
            return .blue
        case "purple":
            return .purple
        case "orange":
            return .orange
        case "green":
            return .green
        case "indigo":
            return .indigo
        default:
            return .semantic(.brandPrimary)
        }
    }
}

// MARK: - Preview

#Preview("Emotional Tone Insight") {
    PersonalInsightCardView(
        insight: PersonalInsight(
            type: .emotionalTone,
            observation: "Your tone suggests curiosity mixed with concern about the future.",
            invitation: "What if you sat with the curiosity and let the concern rest for now?"
        )
    )
    .padding()
}

#Preview("Word Pattern Insight") {
    PersonalInsightCardView(
        insight: PersonalInsight(
            type: .wordPattern,
            observation: "I notice you used 'should' 4 times in 2 minutes—do you feel that pressure?",
            invitation: "What would happen if you replaced 'should' with 'could'?"
        )
    )
    .padding()
}

#Preview("Value Glimpse Insight") {
    PersonalInsightCardView(
        insight: PersonalInsight(
            type: .valueGlimpse,
            observation: "Authenticity seems important to you—you lit up when discussing 'being real' at work.",
            invitation: "Where else in your life is authenticity calling you?"
        )
    )
    .padding()
}
