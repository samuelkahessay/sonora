//
//  DistillPartialResultView.swift
//  Sonora
//
//  Created by Claude on 2025-11-04.
//  Progressive rendering of partial distill results during SSE streaming
//

import SwiftUI

/// Renders partial distill results as they arrive via SSE streaming
/// Reuses existing section components from DistillResultView for consistency
struct DistillPartialResultView: View {
    let partialData: PartialDistillData

    // Pro gating
    private var isPro: Bool { DIContainer.shared.storeKitService().isPro }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Summary Section (always first, base component - appears at 1/4)
            if let summary = partialData.summary, !summary.isEmpty {
                DistillSummarySectionView(summary: summary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Action Items Section (simplified - no add functionality during streaming)
            if let actionItems = partialData.actionItems, !actionItems.isEmpty {
                actionItemsSection(items: actionItems)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Reflection Questions Section (appears with base at 1/4)
            if let questions = partialData.reflectionQuestions, !questions.isEmpty {
                ReflectionQuestionsSectionView(questions: questions)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Pro-tier analysis sections (appear progressively at 2/4, 3/4, 4/4)
            if isPro {
                // Only show divider if we have Pro content
                if hasProContent {
                    Divider()
                        .padding(.vertical, 8)
                        .transition(.opacity)
                }

                // Thinking Patterns Section (appears at 2/4)
                if let patterns = partialData.thinkingPatterns, !patterns.isEmpty {
                    ThinkingPatternsSectionView(patterns: patterns)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Philosophical Echoes Section (appears at 3/4)
                if let echoes = partialData.philosophicalEchoes, !echoes.isEmpty {
                    PhilosophicalEchoesSectionView(echoes: echoes)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Values Insights Section (appears at 4/4)
                if let values = partialData.valuesInsights {
                    ValuesInsightSectionView(insight: values)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: partialData)
        .textSelection(.enabled)
    }

    // MARK: - Helpers

    /// Check if we have any Pro content to show
    private var hasProContent: Bool {
        guard isPro else { return false }

        return (partialData.thinkingPatterns?.isEmpty == false) ||
               (partialData.philosophicalEchoes?.isEmpty == false) ||
               (partialData.valuesInsights != nil)
    }

    /// Simple action items list (read-only during streaming)
    @ViewBuilder
    private func actionItemsSection(items: [DistillData.ActionItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(Color.semantic(.brandPrimary))

                Text("Action Items")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)

                Spacer()
            }

            // Action items list (simplified - no add/edit during streaming)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        // Bullet or number
                        Text("\(index + 1).")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                            .frame(width: 24, alignment: .trailing)

                        // Action text
                        Text(item.text)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color.semantic(.brandPrimary).opacity(0.05))
            .cornerRadius(8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Action Items: \(items.count) items")
    }
}

// MARK: - Preview
#Preview("Partial Results - Progressive Loading") {
    ScrollView {
        VStack(spacing: 30) {
            // Stage 1: Only base summary (1/4 complete)
            VStack(alignment: .leading) {
                Text("Stage 1: Base Summary (1/4)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)

                DistillPartialResultView(
                    partialData: PartialDistillData(
                        summary: "This memo captures your thoughts about the importance of morning routines and their impact on productivity. You mentioned how starting the day with intention helps maintain focus throughout the day.",
                        actionItems: nil,
                        reflectionQuestions: ["How might you refine your morning routine to better serve your goals?", "What would happen if you experimented with a different morning structure?"],
                        thinkingPatterns: nil,
                        philosophicalEchoes: nil,
                        valuesInsights: nil
                    )
                )
            }

            Divider()

            // Stage 2: + Thinking Patterns (2/4 complete)
            VStack(alignment: .leading) {
                Text("Stage 2: + Thinking Patterns (2/4)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)

                DistillPartialResultView(
                    partialData: PartialDistillData(
                        summary: "This memo captures your thoughts about the importance of morning routines and their impact on productivity.",
                        actionItems: [
                            DistillData.ActionItem(text: "Experiment with waking up 30 minutes earlier", priority: .medium)
                        ],
                        reflectionQuestions: ["How might you refine your morning routine to better serve your goals?"],
                        thinkingPatterns: [
                            ThinkingPattern(type: .pressureLanguage, observation: "You're using 'should' and 'must' language when describing your routines", reframe: "Consider replacing 'should' with 'could' to reduce internal pressure")
                        ],
                        philosophicalEchoes: nil,
                        valuesInsights: nil
                    )
                )
            }

            Divider()

            // Stage 3: + Philosophical Echoes (3/4 complete)
            VStack(alignment: .leading) {
                Text("Stage 3: + Wisdom (3/4)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)

                DistillPartialResultView(
                    partialData: PartialDistillData(
                        summary: "This memo captures your thoughts about the importance of morning routines.",
                        actionItems: [
                            DistillData.ActionItem(text: "Experiment with waking up 30 minutes earlier", priority: .medium)
                        ],
                        reflectionQuestions: ["How might you refine your morning routine?"],
                        thinkingPatterns: [
                            ThinkingPattern(type: .pressureLanguage, observation: "You're using 'should' and 'must' language when describing your routines", reframe: nil)
                        ],
                        philosophicalEchoes: [
                            PhilosophicalEcho(
                                tradition: .stoicism,
                                connection: "Your focus on morning routines echoes the Stoic practice of morning preparation",
                                quote: "When you arise in the morning, think of what a precious privilege it is to be alive",
                                source: "Marcus Aurelius"
                            )
                        ],
                        valuesInsights: nil
                    )
                )
            }
        }
        .padding()
    }
}
