import SwiftUI

struct AnalysisResultsView: View {
    let payload: AnalysisResultPayload
    let memoId: UUID?

    var body: some View {
        // Avoid nested ScrollViews; parent provides scrolling.
        VStack(alignment: .leading, spacing: 16) {
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
            case .liteDistill(let data, let env):
                LiteDistillResultView(data: data, envelope: env)
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
                    .font(SonoraDesignSystem.Typography.headingMedium)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(envelope.model)
                        .font(SonoraDesignSystem.Typography.metadata)
                        .foregroundColor(.semantic(.textSecondary))
                        .accessibilityLabel("AI model: \(envelope.model)")
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    Text("\(envelope.latency_ms)ms")
                        .font(SonoraDesignSystem.Typography.metadata)
                        .foregroundColor(.semantic(.textSecondary))
                        .accessibilityLabel("Response time: \(envelope.latency_ms) milliseconds")
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                }
            }

            HStack {
                Label("\(envelope.tokens.input + envelope.tokens.output) tokens", systemImage: "textformat")
                    .font(SonoraDesignSystem.Typography.metadata)
                    .foregroundColor(.semantic(.textSecondary))
                    .accessibilityLabel("Total tokens used: \(envelope.tokens.input + envelope.tokens.output)")
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)

                Spacer()

                Text("\(envelope.tokens.input) in, \(envelope.tokens.output) out")
                    .font(SonoraDesignSystem.Typography.metadata)
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
