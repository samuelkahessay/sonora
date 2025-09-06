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
    @State private var insightHintOpacity: Double = 0
    @State private var waveformShimmer: Bool = false
    
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
            // Header with timestamp and waveform preview
            headerSection
            
            // Title with thoughtful typography
            titleSection
            
            // Metadata row with duration and insights
            metadataSection
            

        }
        .padding(.all, SonoraDesignSystem.Spacing.breathingRoom)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SonoraDesignSystem.Spacing.cardRadius))
        .shadow(
            color: Color.sonoraDep.opacity(0.08),
            radius: 8, x: 0, y: 4
        )
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
    
    /// Header section with contextual timestamp
    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .top) {
            Text(contextualTimeString)
                .font(SonoraDesignSystem.Typography.caption)
                .foregroundColor(.reflectionGray)
            
            Spacer()
            
            if transcriptionState.isInProgress {
                // Gentle pulse for active transcription
                Circle()
                    .fill(Color.insightGold)
                    .frame(width: 6, height: 6)
                    .opacity(waveformShimmer ? 0.4 : 1.0)
            }
        }
    }
    
    /// Title section with premium typography
    @ViewBuilder
    private var titleSection: some View {
        Text(memo.displayName)
            .font(SonoraDesignSystem.Typography.headingSmall)
            .foregroundColor(.textPrimary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
    
    /// Metadata section with duration and insight hints
    @ViewBuilder
    private var metadataSection: some View {
        HStack(spacing: SonoraDesignSystem.Spacing.md) {
            // Duration with subtle icon
            HStack(spacing: SonoraDesignSystem.Spacing.iconToTextSpacing) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.reflectionGray)
                
                Text(memo.durationString)
                    .font(SonoraDesignSystem.Typography.caption)
                    .foregroundColor(.reflectionGray)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Insight teaser (if available)
            if hasInsights {
                insightHintView
            }
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
        if transcriptionState.isInProgress {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.insightGold)
                .frame(width: 4, height: 16)
                .padding(.trailing, 4)
                .padding(.top, 4)
        }
    }
    
    /// Card background with whisper blue tint
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: SonoraDesignSystem.Spacing.cardRadius)
            .fill(Color.clarityWhite)
            .overlay(
                RoundedRectangle(cornerRadius: SonoraDesignSystem.Spacing.cardRadius)
                    .fill(Color.whisperBlue.opacity(0.3))
            )
    }
    
    // MARK: - Helper Properties
    
    /// Contextual time string that complements section headers rather than repeating them
    private var contextualTimeString: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(memo.creationDate) {
            // For today's memos, show relative time (e.g., "2 hours ago", "Just now")
            let timeInterval = now.timeIntervalSince(memo.creationDate)
            
            if timeInterval < 60 {
                return "Just now"
            } else if timeInterval < 3600 {
                let minutes = Int(timeInterval / 60)
                return "\(minutes)m ago"
            } else if timeInterval < 86400 {
                let hours = Int(timeInterval / 3600)
                return "\(hours)h ago"
            } else {
                // Fallback to specific time for edge cases
                return DateFormatter.timeOnly.string(from: memo.creationDate)
            }
        } else if calendar.isDateInYesterday(memo.creationDate) {
            // For yesterday's memos, show specific time instead of repeating "Yesterday"
            return DateFormatter.timeOnly.string(from: memo.creationDate)
        } else {
            // For older memos, show date and time to distinguish from section header
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: memo.creationDate)
        }
    }
    

    
    // MARK: - Animation Helpers
    
    private func configureAnimations() {
        // Gentle shimmer for active states
        if transcriptionState.isInProgress {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                waveformShimmer = true
            }
        }
        
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
