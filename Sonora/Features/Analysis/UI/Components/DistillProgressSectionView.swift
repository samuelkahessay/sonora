//
//  DistillProgressSectionView.swift
//  Sonora
//
//  Created by Claude on 2025-11-04.
//  Progressive loading UI for SSE streaming distill analysis
//

import SwiftUI

/// Progress indicator showing completion status during SSE streaming
struct DistillProgressSectionView: View {
    let progress: AnalysisStreamingUpdate

    /// Calculates progress value from completed/total count
    private var progressValue: Double {
        guard progress.totalCount > 0 else { return 0 }
        return Double(progress.completedCount) / Double(progress.totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Progress bar
            ProgressView(value: progressValue)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.semantic(.brandPrimary)))
                .accessibilityLabel("Analysis progress")
                .accessibilityValue("\(Int(progressValue * 100)) percent complete")

            // Status text with component count
            HStack {
                Text("Processing Components")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(progress.completedCount)/\(progress.totalCount)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Processing components, \(progress.completedCount) of \(progress.totalCount) complete")

            // Current component badge with animation
            if let component = progress.component {
                ComponentBadge(componentName: component)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: component)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Preview
#Preview("Progress Section") {
    VStack(spacing: 20) {
        // Stage 1: Base summary processing
        DistillProgressSectionView(
            progress: AnalysisStreamingUpdate(
                partialText: nil,
                component: "base",
                completedCount: 1,
                totalCount: 4,
                partialData: nil,
                isFinal: false
            )
        )

        // Stage 2: Thinking patterns processing
        DistillProgressSectionView(
            progress: AnalysisStreamingUpdate(
                partialText: nil,
                component: "thinkingPatterns",
                completedCount: 2,
                totalCount: 4,
                partialData: nil,
                isFinal: false
            )
        )

        // Stage 3: Wisdom processing
        DistillProgressSectionView(
            progress: AnalysisStreamingUpdate(
                partialText: nil,
                component: "philosophicalEchoes",
                completedCount: 3,
                totalCount: 4,
                partialData: nil,
                isFinal: false
            )
        )

        // Stage 4: Values processing
        DistillProgressSectionView(
            progress: AnalysisStreamingUpdate(
                partialText: nil,
                component: "valuesInsights",
                completedCount: 4,
                totalCount: 4,
                partialData: nil,
                isFinal: false
            )
        )
    }
    .padding()
}
