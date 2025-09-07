import SwiftUI

/// Comprehensive view for displaying Distill analysis results
/// Shows summary, action items, themes, and reflection questions in a mentor-like format
/// Supports progressive rendering of partial data as components complete
struct DistillResultView: View {
    let data: DistillData?
    let envelope: AnalyzeEnvelope<DistillData>?
    let partialData: PartialDistillData?
    let progress: DistillProgressUpdate?
    
    // Convenience initializers for backward compatibility
    init(data: DistillData, envelope: AnalyzeEnvelope<DistillData>) {
        self.data = data
        self.envelope = envelope
        self.partialData = nil
        self.progress = nil
    }
    
    init(partialData: PartialDistillData, progress: DistillProgressUpdate) {
        self.data = partialData.toDistillData()
        self.envelope = nil
        self.partialData = partialData
        self.progress = progress
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Progress indicator for parallel processing
            if let progress = progress, progress.completedComponents < progress.totalComponents {
                progressSection(progress)
            }
            
            // Summary Section
            if let summary = effectiveSummary {
                summarySection(summary)
            } else if isShowingProgress {
                summaryPlaceholder
            }
            
            // Action Items Section (only shown if present)
            if let actionItems = effectiveActionItems, !actionItems.isEmpty {
                actionItemsSection(actionItems)
            } else if isShowingProgress && shouldShowActionItemsPlaceholder {
                actionItemsPlaceholder
            }
            
            // Key Themes Section
            if let keyThemes = effectiveKeyThemes, !keyThemes.isEmpty {
                keyThemesSection(keyThemes)
            } else if isShowingProgress {
                keyThemesPlaceholder
            }
            
            // Reflection Questions Section
            if let reflectionQuestions = effectiveReflectionQuestions, !reflectionQuestions.isEmpty {
                reflectionQuestionsSection(reflectionQuestions)
            } else if isShowingProgress {
                reflectionQuestionsPlaceholder
            }
            
            // Performance info
            if let envelope = envelope {
                performanceInfo(envelope)
            } else if let progress = progress {
                progressPerformanceInfo(progress)
            }
        }
        .padding()
        .background(Color.semantic(.bgSecondary))
        .cornerRadius(12)
        .shadow(color: Color.semantic(.separator).opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Computed Properties
    
    private var isShowingProgress: Bool {
        progress != nil && partialData != nil
    }
    
    private var effectiveSummary: String? {
        return data?.summary ?? partialData?.summary
    }
    
    private var effectiveActionItems: [DistillData.ActionItem]? {
        return data?.action_items ?? partialData?.actionItems
    }
    
    private var effectiveKeyThemes: [String]? {
        return data?.key_themes ?? partialData?.keyThemes
    }
    
    private var effectiveReflectionQuestions: [String]? {
        return data?.reflection_questions ?? partialData?.reflectionQuestions
    }
    
    private var shouldShowActionItemsPlaceholder: Bool {
        // Only show placeholder if we haven't received action items yet
        return partialData?.actionItems == nil
    }
    
    // MARK: - Progress Section
    
    @ViewBuilder
    private func progressSection(_ progress: DistillProgressUpdate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Processing Components (\(progress.completedComponents)/\(progress.totalComponents))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let latestComponent = progress.latestComponent {
                    Text(latestComponent.displayName)
                        .font(.caption)
                        .foregroundColor(.semantic(.success))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.semantic(.success).opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            ProgressView(value: progress.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .semantic(.brandPrimary)))
        }
        .padding(12)
        .background(Color.semantic(.brandPrimary).opacity(0.05))
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.3), value: progress.completedComponents)
    }
    
    // MARK: - Summary Section
    
    @ViewBuilder
    private func summarySection(_ summary: String) -> some View {
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
            
            Text(summary)
                .font(.body)
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
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
                            .multilineTextAlignment(.leading)
                        
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
    private func keyThemesSection(_ themes: [String]) -> some View {
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
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                ForEach(themes, id: \.self) { theme in
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
    private func reflectionQuestionsSection(_ questions: [String]) -> some View {
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
                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
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
                            .multilineTextAlignment(.leading)
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
    
    // MARK: - Placeholder Views
    
    @ViewBuilder
    private var summaryPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                Text("Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textSecondary))
                
                Spacer()
                
                LoadingIndicator(size: .small)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.semantic(.separator).opacity(0.3))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.semantic(.separator).opacity(0.3))
                    .frame(height: 12)
                    .scaleEffect(x: 0.75, anchor: .leading)
            }
        }
        .redacted(reason: .placeholder)
        .frame(minHeight: 130)
    }
    
    @ViewBuilder
    private var actionItemsPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                Text("Action Items")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textSecondary))
                
                Spacer()
                
                LoadingIndicator(size: .small)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.semantic(.separator).opacity(0.3))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.semantic(.separator).opacity(0.3))
                            .frame(height: 12)
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
        .frame(minHeight: 180)
    }
    
    @ViewBuilder
    private var keyThemesPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "tag.circle")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                Text("Key Themes")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textSecondary))
                
                Spacer()
                
                LoadingIndicator(size: .small)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.semantic(.separator).opacity(0.2))
                        .frame(width: index == 0 ? 80 : (index == 1 ? 65 : 100), height: 28)
                }
            }
        }
        .redacted(reason: .placeholder)
        .frame(minHeight: 120)
    }
    
    @ViewBuilder
    private var reflectionQuestionsPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                Text("Reflection Questions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textSecondary))
                
                Spacer()
                
                LoadingIndicator(size: .small)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.semantic(.textSecondary))
                            .frame(minWidth: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.semantic(.separator).opacity(0.3))
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.semantic(.separator).opacity(0.3))
                                .frame(height: 12)
                                .scaleEffect(x: 0.6, anchor: .leading)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.semantic(.separator).opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .redacted(reason: .placeholder)
        .frame(minHeight: 180)
    }
    
    // MARK: - Performance Info
    
    @ViewBuilder
    private func performanceInfo(_ envelope: AnalyzeEnvelope<DistillData>) -> some View {
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
    
    @ViewBuilder
    private func progressPerformanceInfo(_ progress: DistillProgressUpdate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
            
            Text("Processing in parallel (\(Int(progress.progress * 100))%)")
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
            
            Spacer()
            
            Text("GPT-5-nano")
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
