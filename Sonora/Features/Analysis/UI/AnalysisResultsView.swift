import SwiftUI

struct AnalysisResultsView: View {
    let payload: AnalysisResultPayload
    let memoId: UUID?

    var body: some View {
        // Avoid nested ScrollViews; parent provides scrolling.
        VStack(alignment: .leading, spacing: 16) {
            // Header with model info (suppressed for Distill and data-only detections)
            switch payload {
            case .analysis(_, let env):
                HeaderInfoView(envelope: env)
            case .themes(_, let env):
                HeaderInfoView(envelope: env)
            case .todos(_, let env):
                HeaderInfoView(envelope: env)
            case .distill, .events, .reminders:
                EmptyView()
            }

            // Moderation warning if flagged
            if payload.isModerationFlagged {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.semantic(.warning))
                    Text("This AI-generated analysis may contain sensitive or harmful content.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
                .padding(8)
                .background(Color.semantic(.warning).opacity(0.08))
                .cornerRadius(8)
            }

            // Mode-specific content
            switch payload {
            case .distill(let data, let env):
                DistillResultView(data: data, envelope: env, memoId: memoId)
            case .analysis(let data, _):
                AnalysisResultView(data: data)
            case .themes(let data, _):
                ThemesResultView(data: data)
            case .todos(let data, _):
                TodosResultView(data: data)
            case .events(let data):
                EventsResultView(data: data)
            case .reminders(let data):
                RemindersResultView(data: data)
            }
        }
        .padding()
    }
}

struct HeaderInfoView<T: Codable & Sendable>: View {
    let envelope: AnalyzeEnvelope<T>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(envelope.mode.displayName)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(envelope.model)
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                        .accessibilityLabel("AI model: \(envelope.model)")
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    Text("\(envelope.latency_ms)ms")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                        .accessibilityLabel("Response time: \(envelope.latency_ms) milliseconds")
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                }
            }

            HStack {
                Label("\(envelope.tokens.input + envelope.tokens.output) tokens", systemImage: "textformat")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                    .accessibilityLabel("Total tokens used: \(envelope.tokens.input + envelope.tokens.output)")
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)

                Spacer()

                Text("\(envelope.tokens.input) in, \(envelope.tokens.output) out")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                    .accessibilityLabel("Input tokens: \(envelope.tokens.input), Output tokens: \(envelope.tokens.output)")
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            }
        }
        .padding()
        .background(Color.semantic(.fillPrimary))
        .cornerRadius(12)
    }
}

struct AnalysisResultView: View {
    let data: AnalysisData

    var body: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.lg) {
            // Summary section with brand typography
            summarySection

            // Key points as insight cards
            keyPointsSection

            // Action items appear in Distill results, not Analysis
        }
        .padding(.all, SonoraDesignSystem.Spacing.breathingRoom)
    }

    // MARK: - View Components

    /// Summary section with thoughtful typography
    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.sm) {
            Text("Summary")
                .font(SonoraDesignSystem.Typography.headingMedium)
                .foregroundColor(.textPrimary)

            Text(data.summary)
                .font(SonoraDesignSystem.Typography.bodyLarge)
                .foregroundColor(.textPrimary)
                .lineSpacing(6)
        }
        .padding(.all, SonoraDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clarityWhite)
                .shadow(color: Color.sonoraDep.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    /// Key points as branded insight cards
    @ViewBuilder
    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.md) {
            Text("Key Insights")
                .font(SonoraDesignSystem.Typography.headingMedium)
                .foregroundColor(.textPrimary)

            // Convert key points to insight cards
            ForEach(Array(data.key_points.enumerated()), id: \.offset) { index, point in
                SonoraInsightCard(
                    insight: InsightData(
                        text: point,
                        category: "Insight",
                        confidence: 0.8,
                        source: "Analysis"
                    ),
                    isHighlighted: index == 0 // Highlight first insight
                )
            }
        }
    }

    // (No action items for AnalysisData)
}

struct ThemesResultView: View {
    let data: ThemesData

    private var sentimentColor: Color {
        switch data.sentiment.lowercased() {
        case "positive": return .growthGreen
        case "negative": return .sparkOrange
        case "mixed": return .insightGold
        default: return .reflectionGray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.lg) {
            // Sentiment indicator with brand styling
            sentimentSection

            // Themes as insight cards
            themesSection
        }
        .padding(.all, SonoraDesignSystem.Spacing.breathingRoom)
    }

    // MARK: - View Components

    /// Sentiment section with brand colors
    @ViewBuilder
    private var sentimentSection: some View {
        HStack {
            Text("Emotional Tone")
                .font(SonoraDesignSystem.Typography.headingMedium)
                .foregroundColor(.textPrimary)

            Spacer()

            Text(data.sentiment.capitalized)
                .font(SonoraDesignSystem.Typography.bodyRegular)
                .fontWeight(.medium)
                .padding(.horizontal, SonoraDesignSystem.Spacing.md)
                .padding(.vertical, SonoraDesignSystem.Spacing.xs)
                .background(sentimentColor.opacity(0.2))
                .foregroundColor(sentimentColor)
                .clipShape(Capsule())
        }
        .padding(.all, SonoraDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clarityWhite)
                .shadow(color: Color.sonoraDep.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    /// Themes section with branded cards
    @ViewBuilder
    private var themesSection: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.md) {
            Text("Recurring Themes")
                .font(SonoraDesignSystem.Typography.headingMedium)
                .foregroundColor(.textPrimary)

            ForEach(Array(data.themes.enumerated()), id: \.offset) { index, theme in
                SonoraInsightCard(
                    insight: InsightData(
                        text: createThemeInsightText(theme),
                        category: "Theme",
                        confidence: 0.85,
                        source: "Pattern Recognition"
                    ),
                    isHighlighted: index == 0
                )
            }
        }
    }

    /// Create insight text from theme data
    private func createThemeInsightText(_ theme: ThemesData.Theme) -> String {
        let evidenceText = theme.evidence.prefix(2).joined(separator: " ... ")
        return "\(theme.name): \(evidenceText)"
    }

}

struct TodosResultView: View {
    let data: TodosData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Action Items")
                .font(.headline)
                .fontWeight(.semibold)

            if data.todos.isEmpty {
                UnifiedStateView(
                    state: .empty(
                        icon: "checkmark.circle.fill",
                        title: "No Action Items",
                        subtitle: "No actionable tasks were found in this transcription"
                    )
                )
            } else {
                ForEach(Array(data.todos.enumerated()), id: \.offset) { _, todo in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "circle")
                            .font(.body)
                            .foregroundColor(.semantic(.brandPrimary))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(todo.text)
                                .font(.body)
                                .lineSpacing(2)

                            if let dueDate = todo.dueDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.semantic(.warning))
                                    Text(formatDate(dueDate))
                                        .font(.caption)
                                        .foregroundColor(.semantic(.warning))
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
