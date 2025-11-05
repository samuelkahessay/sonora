import SwiftUI

/// Displays thinking patterns observed through language analysis
/// Shows recurring speech habits with observations and alternative perspectives
/// Pro-tier feature
internal struct ThinkingPatternsSectionView: View {
    let patterns: [ThinkingPattern]

    @ScaledMetric private var sectionSpacing: CGFloat = 12
    @ScaledMetric private var headerSpacing: CGFloat = 6
    @ScaledMetric private var patternSpacing: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "brain.head.profile")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.accent))
                Text("Thinking Patterns")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))

                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundColor(.semantic(.brandPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Thinking Patterns section, Pro feature, \(patterns.count) patterns detected")

            if patterns.isEmpty {
                EmptyThinkingPatternsState()
            } else {
                VStack(alignment: .leading, spacing: patternSpacing) {
                    ForEach(patterns) { pattern in
                        ThinkingPatternCard(pattern: pattern)
                    }
                }
            }
        }
    }
}

/// Individual thinking pattern card showing pattern type, observation, and alternative perspective
private struct ThinkingPatternCard: View {
    let pattern: ThinkingPattern

    @ScaledMetric private var cardPadding: CGFloat = 12
    @ScaledMetric private var contentSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            // Pattern type with icon
            HStack(spacing: 6) {
                Image(systemName: pattern.type.iconName)
                    .font(.caption)
                    .foregroundColor(.semantic(.accent))

                Text(pattern.type.displayName)
                    .font(SonoraDesignSystem.Typography.cardBody)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }

            // Brief description of the pattern type
            Text(pattern.type.description)
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
                .italic()

            // Observation from the memo
            VStack(alignment: .leading, spacing: 4) {
                Text("Observation")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.semantic(.textSecondary))

                Text(pattern.observation)
                    .font(SonoraDesignSystem.Typography.cardBody)
                    .foregroundColor(.semantic(.textPrimary))
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
            }

            // Optional reframe
            if let reframe = pattern.reframe {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                        Text("Reframe")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.semantic(.success))

                    Text(reframe)
                        .font(SonoraDesignSystem.Typography.cardBody)
                        .foregroundColor(.semantic(.textPrimary))
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .padding(8)
                        .background(
                            Color.semantic(.success).opacity(0.08)
                        )
                        .cornerRadius(6)
                }
            }
        }
        .padding(cardPadding)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.semantic(.accent).opacity(0.06),
                    Color.semantic(.accent).opacity(0.03)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Thinking pattern: \(pattern.type.displayName). \(pattern.observation)")
    }
}

/// Empty state shown when no thinking patterns are detected
private struct EmptyThinkingPatternsState: View {
    @ScaledMetric private var emptyStatePadding: CGFloat = 12
    @ScaledMetric private var emptyStateSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: emptyStateSpacing) {
            Text("Clear and balanced communication")
                .font(.body)
                .foregroundColor(.semantic(.textSecondary))
                .fontWeight(.medium)

            Text("No concerning speech patterns detected in this memo. Your thinking appears clear and well-grounded.")
                .font(.callout)
                .foregroundColor(.semantic(.textTertiary))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
        }
        .padding(emptyStatePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.semantic(.success).opacity(0.05)
        )
        .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No concerning thinking patterns detected. Clear and balanced communication.")
    }
}
