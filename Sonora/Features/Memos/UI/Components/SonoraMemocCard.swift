//
//  SonoraMemocCard.swift
//  Sonora
//
//  Premium memo card component implementing Sonora brand identity
//  Features organic waveform shadows, insight hints, and thoughtful spacing
//

import SwiftUI

// MARK: - SonoraMemocCard

/// Premium memo card component that embodies the "Clarity through Voice" brand identity
///
/// **Design Philosophy:**
/// - Organic waveform shadows using brand colors
/// - Progressive insight revelation for engagement
/// - 24pt breathing margins for mental calm
/// - Growth Green accents for discovered insights
///
/// **Brand Integration:**
/// - Uses SonoraBrandColors semantic color system
/// - Follows SonoraDesignSystem spacing and typography
/// - Implements gentle spring animations for organic feel
struct SonoraMemocCard: View {
    
    // MARK: - Properties
    
    let memo: Memo
    @ObservedObject var viewModel: MemoListViewModel
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var insightHintOpacity: Double = 0
    
    // MARK: - Computed Properties
    
    private var transcriptionState: TranscriptionState {
        viewModel.getTranscriptionState(for: memo)
    }
    
    private var hasInsights: Bool {
        // Check if memo has analysis results with insights
        memo.analysisResults.contains(where: { result in
            if let content = result.content { return !content.isEmpty }
            return false
        })
    }
    
    // MARK: - View Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.md) {
            // Title with thoughtful typography
            titleSection
            
            // Unified metadata row: duration · relative time (+ optional insights)
            metadataRow
            

        }
        // Consistent, compact vertical rhythm with generous horizontal padding
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SonoraDesignSystem.Spacing.cardRadius))
        .shadow(
            color: colorScheme == .dark
                ? Color.white.opacity(0.05) // subtle highlight in dark mode
                : Color.sonoraDep.opacity(0.08),
            radius: 8, x: 0, y: 4
        )
        // Inline chevron inside card bounds (instead of List accessory)
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.trailing, 12)
        }
        .overlay(alignment: .topTrailing) {
            // Subtle state indicator
            stateIndicator
        }
        .onAppear {
            configureAnimations()
        }
        .onChange(of: hasInsights) { _, newValue in
            if newValue {
                animateInsightHint()
            }
        }
    }
    
    // MARK: - View Components
    
    /// Title section with premium typography
    @ViewBuilder
    private var titleSection: some View {
        Text(memo.displayName)
            .font(SonoraDesignSystem.Typography.headingSmall)
            .foregroundColor(.semantic(.textPrimary))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
    
    /// Unified metadata row with duration and relative time (single source of truth)
    @ViewBuilder
    private var metadataRow: some View {
        HStack(spacing: SonoraDesignSystem.Spacing.iconToTextSpacing) {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(memo.durationString) · \(relativeTime)")
                .font(.footnote)
                .foregroundColor(.secondary)
                .monospacedDigit()
            
            Spacer(minLength: 0)
            
            // Insight teaser (if available)
            if hasInsights { insightHintView }
        }
    }
    

    
    /// Insight hint view with Growth Green accent
    @ViewBuilder
    private var insightHintView: some View {
        HStack(spacing: 4) {
            Image(systemName: "lightbulb.fill")
                .font(.caption2)
                .foregroundColor(.growthGreen)
            
            Text("Insights")
                .font(SonoraDesignSystem.Typography.caption)
                .foregroundColor(.growthGreen)
        }
        .opacity(insightHintOpacity)
        .scaleEffect(insightHintOpacity == 0 ? 0.8 : 1.0)
    }
    
    /// Subtle state indicator
    @ViewBuilder
    private var stateIndicator: some View {
        // Removed transcription progress indicator for cleaner card design
        EmptyView()
    }
    
    /// Card background with whisper blue tint
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: SonoraDesignSystem.Spacing.cardRadius)
            .fill(colorScheme == .dark
                  ? Color.semantic(.bgSecondary)
                  : Color.clarityWhite)
            .overlay(
                RoundedRectangle(cornerRadius: SonoraDesignSystem.Spacing.cardRadius)
                    .fill(colorScheme == .dark
                          ? Color.clear
                          : Color.whisperBlue.opacity(0.3))
            )
    }
    
    // MARK: - Helper Properties
    
    /// Relative time string in compact system style (e.g., "1m ago", "2h ago")
    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let now = Date()
        let endDate = min(memo.recordingEndDate, now)
        return formatter.localizedString(for: endDate, relativeTo: now)
    }
    

    
    // MARK: - Animation Helpers
    
    private func configureAnimations() {
        // Removed shimmer animation during transcription for cleaner UI
        // Animate insight hint if insights exist
        if hasInsights {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateInsightHint()
            }
        }
    }
    
    private func animateInsightHint() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            insightHintOpacity = 1.0
        }
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
