import SwiftUI

/// Comprehensive view for displaying Distill analysis results
/// Shows summary, action items, themes, and reflection questions in a mentor-like format
struct DistillResultView: View {
    let data: DistillData
    let envelope: AnalyzeEnvelope<DistillData>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Summary Section
            summarySection
            
            // Action Items Section (only shown if present)
            if let actionItems = data.action_items, !actionItems.isEmpty {
                actionItemsSection(actionItems)
            }
            
            // Key Themes Section
            keyThemesSection
            
            // Reflection Questions Section
            reflectionQuestionsSection
            
            // Performance info
            performanceInfo
        }
    }
    
    // MARK: - Summary Section
    
    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }
            
            Text(data.summary)
                .font(.body)
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Action Items Section
    
    @ViewBuilder
    private func actionItemsSection(_ items: [DistillData.ActionItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.success))
                Text("Action Items")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.text) { item in
                    HStack(alignment: .top, spacing: 10) {
                        // Priority indicator
                        Circle()
                            .fill(priorityColor(item.priority))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        
                        // Action text
                        Text(item.text)
                            .font(.body)
                            .foregroundColor(.semantic(.textPrimary))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 0)
                        
                        // Priority badge
                        Text(item.priority.rawValue.capitalized)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(priorityColor(item.priority))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.semantic(.fillSecondary))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Key Themes Section
    
    @ViewBuilder
    private var keyThemesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "tag.circle")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.info))
                Text("Key Themes")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }
            
            FlowLayout(spacing: 8) {
                ForEach(data.key_themes, id: \.self) { theme in
                    Text(theme)
                        .font(.callout)
                        .foregroundColor(.semantic(.textPrimary))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.semantic(.brandPrimary).opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.semantic(.brandPrimary).opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(6)
                }
            }
        }
    }
    
    // MARK: - Reflection Questions Section
    
    @ViewBuilder
    private var reflectionQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.warning))
                Text("Reflection Questions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(data.reflection_questions.enumerated()), id: \.offset) { index, question in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.semantic(.textSecondary))
                            .frame(minWidth: 20)
                        
                        Text(question)
                            .font(.callout)
                            .foregroundColor(.semantic(.textPrimary))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.semantic(.warning).opacity(0.05),
                                Color.semantic(.warning).opacity(0.02)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Performance Info
    
    @ViewBuilder
    private var performanceInfo: some View {
        HStack(spacing: 12) {
            Image(systemName: "speedometer")
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
            
            Text("Analysis completed in \(envelope.latency_ms)ms")
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
            
            Spacer()
            
            Text(envelope.model)
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Methods
    
    private func priorityColor(_ priority: DistillData.ActionItem.Priority) -> Color {
        switch priority {
        case .high:
            return .semantic(.error)
        case .medium:
            return .semantic(.warning)
        case .low:
            return .semantic(.success)
        }
    }
}

// MARK: - Flow Layout for Themes

/// A custom layout that arranges views in a flowing horizontal layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.frames[index].origin.x + bounds.minX,
                                     y: result.frames[index].origin.y + bounds.minY),
                         proposal: ProposedViewSize(result.frames[index].size))
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxX: CGFloat = 0
            
            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)
                
                if currentX + viewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: viewSize))
                lineHeight = max(lineHeight, viewSize.height)
                currentX += viewSize.width + spacing
                maxX = max(maxX, currentX)
            }
            
            size = CGSize(width: maxX - spacing, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DistillResultView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            DistillResultView(
                data: DistillData(
                    summary: "This voice memo discusses the implementation of a new feature for the app, focusing on user experience improvements and technical considerations.",
                    action_items: [
                        DistillData.ActionItem(text: "Review the current UI design", priority: .high),
                        DistillData.ActionItem(text: "Schedule meeting with design team", priority: .medium),
                        DistillData.ActionItem(text: "Document API changes", priority: .low)
                    ],
                    key_themes: ["User Experience", "Technical Debt", "Performance", "Team Collaboration"],
                    reflection_questions: [
                        "How might this feature impact our existing user base?",
                        "What are the potential risks we haven't considered?",
                        "How can we measure the success of this implementation?"
                    ]
                ),
                envelope: AnalyzeEnvelope(
                    mode: .distill,
                    data: DistillData(
                        summary: "",
                        action_items: nil,
                        key_themes: [],
                        reflection_questions: []
                    ),
                    model: "gpt-4",
                    tokens: TokenUsage(input: 500, output: 200),
                    latency_ms: 1200,
                    moderation: nil
                )
            )
            .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif