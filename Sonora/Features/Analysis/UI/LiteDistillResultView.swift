import SwiftUI
import UIKit

/// View for displaying Lite Distill analysis results (free tier)
/// Focused clarity with ONE personal insight via single API call
/// Optimized for cost efficiency while delivering meaningful value
struct LiteDistillResultView: View {
    let data: LiteDistillData
    let envelope: AnalyzeEnvelope<LiteDistillData>

    @ScaledMetric private var sectionSpacing: CGFloat = 20
    @ScaledMetric private var headerSpacing: CGFloat = 6
    @ScaledMetric private var contentSpacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            // Summary Section
            summarySectionView

            // Key Themes Section
            if !data.keyThemes.isEmpty {
                keyThemesSectionView
            }

            // Personal Insight (hero component)
            personalInsightSectionView

            // Simple To-dos Section (if any)
            if !data.simpleTodos.isEmpty {
                simpleTodosSectionView
            }

            // Reflection Question Section
            reflectionQuestionSectionView

            // Closing Note
            closingNoteSectionView

            // Copy results action
            copyAction
        }
        .textSelection(.enabled)
    }

    // MARK: - Section Views

    private var summarySectionView: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "text.quote")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Summary")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Summary section")

            Text(data.summary)
                .font(SonoraDesignSystem.Typography.bodyRegular)
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
        }
    }

    private var keyThemesSectionView: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "tag.circle")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Key Themes")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Key themes section")

            // Theme pills/tags
            FlowLayout(spacing: 8) {
                ForEach(data.keyThemes, id: \.self) { theme in
                    Text(theme)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.semantic(.textPrimary))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.semantic(.brandPrimary).opacity(0.1))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.semantic(.brandPrimary).opacity(0.3), lineWidth: 1)
                        )
                        .accessibilityLabel("Theme: \(theme)")
                }
            }
        }
    }

    private var personalInsightSectionView: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "lightbulb.fill")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Personal Insight")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Personal insight section")

            PersonalInsightCardView(insight: data.personalInsight)
        }
    }

    private var simpleTodosSectionView: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "checklist")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Action Items")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Action items section, \(data.simpleTodos.count) items")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(data.simpleTodos) { todo in
                    SimpleTodoRowView(todo: todo)
                }
            }
        }
    }

    private var reflectionQuestionSectionView: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            HStack(spacing: headerSpacing) {
                Image(systemName: "questionmark.circle")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Reflection")
                    .font(SonoraDesignSystem.Typography.sectionHeading)
                    .foregroundColor(.semantic(.textPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reflection question section")

            Text(data.reflectionQuestion)
                .font(SonoraDesignSystem.Typography.bodyRegular)
                .fontWeight(.medium)
                .foregroundColor(.semantic(.textPrimary))
                .italic()
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.semantic(.brandPrimary).opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.semantic(.brandPrimary).opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }

    private var closingNoteSectionView: some View {
        Text(data.closingNote)
            .font(.caption)
            .foregroundColor(.semantic(.textSecondary))
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .padding(.top, 4)
            .accessibilityLabel("Closing note: \(data.closingNote)")
    }

    @ViewBuilder
    private var copyAction: some View {
        HStack {
            Spacer()
            Button(action: {
                let text = buildCopyText()
                UIPasteboard.general.string = text
                HapticManager.shared.playLightImpact()
                NotificationCenter.default.post(name: Notification.Name("AnalysisCopyTriggered"), object: nil)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Copy analysis results")
        }
    }

    // MARK: - Helpers

    private func buildCopyText() -> String {
        var parts: [String] = []

        // Summary
        parts.append("Summary:\n\(data.summary)")

        // Key Themes
        if !data.keyThemes.isEmpty {
            parts.append("Key Themes:\n" + data.keyThemes.map { "• \($0)" }.joined(separator: "\n"))
        }

        // Personal Insight
        var insightLines: [String] = [
            "Personal Insight (\(data.personalInsight.type.displayName)):",
            data.personalInsight.observation
        ]
        if let invitation = data.personalInsight.invitation {
            insightLines.append(invitation)
        }
        parts.append(insightLines.joined(separator: "\n"))

        // Action Items
        if !data.simpleTodos.isEmpty {
            let todoLines = ["Action Items:"] + data.simpleTodos.map { "• \($0.text) [\($0.priority.rawValue)]" }
            parts.append(todoLines.joined(separator: "\n"))
        }

        // Reflection Question
        parts.append("Reflection Question:\n\(data.reflectionQuestion)")

        // Closing Note
        parts.append("Note:\n\(data.closingNote)")

        return parts.joined(separator: "\n\n")
    }
}

// MARK: - FlowLayout Helper

/// Simple flow layout for wrapping theme tags
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview("Lite Distill Result") {
    ScrollView {
        LiteDistillResultView(
            data: LiteDistillData(
                summary: "You explored tensions between work demands and personal boundaries while considering how to communicate your needs more effectively.",
                keyThemes: ["Work-life boundaries", "Self-advocacy", "Stress management"],
                personalInsight: PersonalInsight(
                    type: .wordPattern,
                    observation: "I notice you used 'should' 4 times in 2 minutes—do you feel that pressure?",
                    invitation: "What would happen if you replaced 'should' with 'could'?"
                ),
                simpleTodos: [
                    SimpleTodo(text: "Email team about project boundaries", priority: .high),
                    SimpleTodo(text: "Schedule coffee meeting with Sarah", priority: .medium)
                ],
                reflectionQuestion: "What would honoring your boundaries look like tomorrow?",
                closingNote: "You're developing awareness of your needs—that's wisdom in practice."
            ),
            envelope: AnalyzeEnvelope(
                mode: .liteDistill,
                data: LiteDistillData(
                    summary: "You explored tensions between work demands and personal boundaries while considering how to communicate your needs more effectively.",
                    keyThemes: ["Work-life boundaries", "Self-advocacy", "Stress management"],
                    personalInsight: PersonalInsight(
                        type: .wordPattern,
                        observation: "I notice you used 'should' 4 times in 2 minutes—do you feel that pressure?",
                        invitation: "What would happen if you replaced 'should' with 'could'?"
                    ),
                    simpleTodos: [
                        SimpleTodo(text: "Email team about project boundaries", priority: .high),
                        SimpleTodo(text: "Schedule coffee meeting with Sarah", priority: .medium)
                    ],
                    reflectionQuestion: "What would honoring your boundaries look like tomorrow?",
                    closingNote: "You're developing awareness of your needs—that's wisdom in practice."
                ),
                model: "gpt-5-nano",
                tokens: TokenUsage(input: 500, output: 150),
                latency_ms: 800,
                moderation: nil
            )
        )
        .padding()
    }
    .background(Color.semantic(.bgPrimary))
}
