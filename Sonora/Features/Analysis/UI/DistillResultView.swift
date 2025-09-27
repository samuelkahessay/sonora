import SwiftUI

/// Comprehensive view for displaying Distill analysis results
/// Shows summary, action items, themes, and reflection questions in a mentor-like format
/// Supports progressive rendering of partial data as components complete
import UIKit

struct DistillResultView: View {
    let data: DistillData?
    let envelope: AnalyzeEnvelope<DistillData>?
    let partialData: PartialDistillData?
    let progress: DistillProgressUpdate?
    // Pro gating (Action Items are Pro-only per current plan)
    private var isPro: Bool { DIContainer.shared.storeKitService().isPro }
    @State private var showPaywall: Bool = false
    
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
            
            // Action Items Section (Pro only)
            if isPro, let actionItems = effectiveActionItems, !actionItems.isEmpty {
                actionItemsSection(actionItems)
            } else if isPro && isShowingProgress && shouldShowActionItemsPlaceholder {
                actionItemsPlaceholder
            }
            else if !isPro {
                upgradeCTA
            }
            
            // Reflection Questions Section
            if let reflectionQuestions = effectiveReflectionQuestions, !reflectionQuestions.isEmpty {
                reflectionQuestionsSection(reflectionQuestions)
            } else if isShowingProgress {
                reflectionQuestionsPlaceholder
            }
            
            // Performance info removed for cleaner UI
            
            // Copy results action (also triggers smart transcript expand via notification)
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
        .textSelection(.enabled)
        .sheet(isPresented: $showPaywall) { PaywallView() }
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
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.semantic(.fillSecondary))
                    .cornerRadius(8)
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

    // MARK: - Upgrade CTA (Subtle)
    @ViewBuilder
    private var upgradeCTA: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundColor(.semantic(.brandPrimary))
            VStack(alignment: .leading, spacing: 2) {
                Text("Action Items with Pro")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
                Text("Gentle, tiny next steps tailored to your note")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            }
            Spacer()
            Button("Learn more") {
                HapticManager.shared.playSelection()
                showPaywall = true
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Learn more about Sonora Pro")
        }
        .padding(12)
        .background(Color.semantic(.fillSecondary))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.semantic(.brandPrimary).opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
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
    
    // Performance info removed — simplified progress UI (no technical details)
    
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

    // Build a concatenated text representation for copying
    private func buildCopyText() -> String {
        var parts: [String] = []
        if let s = effectiveSummary, !s.isEmpty {
            parts.append("Summary:\n" + s)
        }
        if let items = effectiveActionItems, !items.isEmpty {
            let list = items.enumerated().map { "\($0.offset + 1). \($0.element.text) [\($0.element.priority.rawValue)]" }.joined(separator: "\n")
            parts.append("Action Items:\n" + list)
        }
        // Key Themes intentionally omitted from Distill (Themes is a separate mode)
        if let questions = effectiveReflectionQuestions, !questions.isEmpty {
            let list = questions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            parts.append("Reflection Questions:\n" + list)
        }
        return parts.joined(separator: "\n\n")
    }

}
