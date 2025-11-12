import SwiftUI

/// Displays patterns and connections across memos
/// Shows how current memo relates to past recordings and recurring themes
internal struct PatternsSectionView: View {
    let patterns: [DistillData.Pattern]

    @ScaledMetric private var sectionSpacing: CGFloat = 12
    @ScaledMetric private var headerSpacing: CGFloat = 6
    @ScaledMetric private var patternSpacing: CGFloat = 16
    @ScaledMetric private var lineSpacing: CGFloat = 2
    @ScaledMetric private var relatedMemoSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "link.circle")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.accentColor)
                Text("Patterns & Connections")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Patterns and Connections section, \(patterns.count) patterns detected")

            VStack(alignment: .leading, spacing: patternSpacing) {
                ForEach(patterns) { pattern in
                    PatternCard(pattern: pattern)
                }
            }
        }
    }
}

/// Individual pattern card showing theme, description, and related memos
private struct PatternCard: View {
    let pattern: DistillData.Pattern

    @ScaledMetric private var cardPadding: CGFloat = 12
    @ScaledMetric private var contentSpacing: CGFloat = 8
    @ScaledMetric private var relatedMemoSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            // Pattern theme
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundColor(.accentColor)

                Text(pattern.theme)
                    .font(SonoraDesignSystem.Typography.cardBody)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }

            // Pattern description
            Text(pattern.description)
                .font(SonoraDesignSystem.Typography.cardBody)
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)

            // Related memos if available
            if let relatedMemos = pattern.relatedMemos, !relatedMemos.isEmpty {
                VStack(alignment: .leading, spacing: relatedMemoSpacing) {
                    ForEach(Array(relatedMemos.prefix(3).enumerated()), id: \.offset) { _, memo in
                        RelatedMemoRow(memo: memo)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(cardPadding)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.semantic(.fillSecondary).opacity(0.05),
                    Color.semantic(.fillSecondary).opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pattern: \(pattern.theme). \(pattern.description)")
    }
}

/// Row showing a related memo reference
private struct RelatedMemoRow: View {
    let memo: DistillData.Pattern.RelatedMemo

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "arrow.turn.up.right")
                .font(.caption2)
                .foregroundColor(.semantic(.textSecondary))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(memo.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.semantic(.textPrimary))

                    if let daysAgo = memo.daysAgo {
                        Text("·")
                            .foregroundColor(.semantic(.textSecondary))
                            .font(.caption2)
                        Text(formatDaysAgo(daysAgo))
                            .font(.caption2)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                }

                if let snippet = memo.snippet {
                    Text(snippet)
                        .font(.caption2)
                        .foregroundColor(.semantic(.textSecondary))
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Related memo: \(memo.title), \(memo.daysAgo.map { formatDaysAgo($0) } ?? "")")
    }

    private func formatDaysAgo(_ days: Int) -> String {
        if days == 0 {
            return "today"
        } else if days == 1 {
            return "yesterday"
        } else if days < 7 {
            return "\(days) days ago"
        } else if days < 14 {
            return "last week"
        } else if days < 30 {
            return "\(days / 7) weeks ago"
        } else {
            return "\(days / 30) months ago"
        }
    }
}
