import SwiftUI

/// Displays values recognition insights
/// Shows detected core values with evidence and confidence, plus value tensions
/// Pro-tier feature
internal struct ValuesInsightSectionView: View {
    let insight: ValuesInsight

    @ScaledMetric private var sectionSpacing: CGFloat = 12
    @ScaledMetric private var headerSpacing: CGFloat = 6
    @ScaledMetric private var valueSpacing: CGFloat = 12
    @ScaledMetric private var tensionSpacing: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "heart.text.square")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Values Recognition")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))

                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundColor(.semantic(.brandPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Values Recognition section, Pro feature, \(insight.coreValues.count) values detected")

            // Core values
            if !insight.coreValues.isEmpty {
                VStack(alignment: .leading, spacing: valueSpacing) {
                    ForEach(insight.coreValues) { value in
                        DetectedValueCard(value: value)
                    }
                }
            }

            // Value tensions
            if let tensions = insight.tensions, !tensions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption)
                            .foregroundColor(.semantic(.warning))
                        Text("Value Tensions")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: valueSpacing) {
                        ForEach(tensions) { tension in
                            ValueTensionCard(tension: tension)
                        }
                    }
                }
            }
        }
    }
}

/// Individual detected value card with evidence and confidence
private struct DetectedValueCard: View {
    let value: ValuesInsight.DetectedValue

    @ScaledMetric private var cardPadding: CGFloat = 12
    @ScaledMetric private var contentSpacing: CGFloat = 8

    private var confidenceColor: Color {
        switch value.confidenceCategory {
        case "High": return .semantic(.success)
        case "Medium": return .semantic(.warning)
        default: return .semantic(.textSecondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            // Value name with confidence badge
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.caption)
                        .foregroundColor(.semantic(.brandPrimary))

                    Text(value.name)
                        .font(SonoraDesignSystem.Typography.cardBody)
                        .fontWeight(.semibold)
                        .foregroundColor(.semantic(.textPrimary))
                }

                Spacer()

                // Confidence indicator
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.caption2)
                    Text(value.confidenceCategory)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(confidenceColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(confidenceColor.opacity(0.12))
                .cornerRadius(4)
            }

            // Evidence
            VStack(alignment: .leading, spacing: 4) {
                Text("Evidence")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.semantic(.textSecondary))

                Text(value.evidence)
                    .font(SonoraDesignSystem.Typography.cardBody)
                    .foregroundColor(.semantic(.textPrimary))
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(cardPadding)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.semantic(.brandPrimary).opacity(0.06),
                    Color.semantic(.brandPrimary).opacity(0.03)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Core value: \(value.name), confidence \(value.confidenceCategory). Evidence: \(value.evidence)")
    }
}

/// Value tension card showing conflict between two values
private struct ValueTensionCard: View {
    let tension: ValuesInsight.ValueTension

    @ScaledMetric private var cardPadding: CGFloat = 10
    @ScaledMetric private var contentSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            // Two values in tension
            HStack(spacing: 8) {
                Text(tension.value1)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))

                Image(systemName: "arrow.left.and.right")
                    .font(.caption2)
                    .foregroundColor(.semantic(.warning))

                Text(tension.value2)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }

            // Observation of how the tension manifests
            Text(tension.observation)
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
        }
        .padding(cardPadding)
        .background(
            Color.semantic(.warning).opacity(0.08)
        )
        .cornerRadius(6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Value tension between \(tension.value1) and \(tension.value2). \(tension.observation)")
    }
}
