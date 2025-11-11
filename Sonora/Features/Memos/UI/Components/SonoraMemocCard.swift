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
    /// Whether to draw a subtle top hairline inside the card to
    /// separate stacked cards within a section.
    var showTopHairline: Bool = false
    /// Stacked group corner treatment
    var isFirstInSection: Bool = false
    var isLastInSection: Bool = false
    @SwiftUI.Environment(\.colorScheme)
    private var colorScheme: ColorScheme
    @State private var insightHintOpacity: Double = 0
    @ObservedObject private var titleCoordinator = DIContainer.shared.titleGenerationCoordinator()

    // MARK: - Computed Properties

    private var hasInsights: Bool {
        // Check if memo has analysis results with insights
        memo.analysisResults.contains { result in
            if let content = result.content { return !content.isEmpty }
            return false
        }
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
        .clipShape(groupClipShape)
        // Subtle inside top hairline (does not affect layout)
        .overlay(alignment: .top) {
            if showTopHairline {
                Rectangle()
                    .fill(hairlineColor)
                    .frame(height: hairlineThickness)
                    .padding(.horizontal, 16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
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
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(primaryTitleText)
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .foregroundColor(.semantic(.textPrimary))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .animation(.easeInOut(duration: 0.2), value: primaryTitleText)

                if streamingTitle != nil, memo.displayName != primaryTitleText {
                    Text(memo.displayName)
                        .font(.subheadline)
                        .foregroundColor(.semantic(.textSecondary))
                        .lineLimit(2)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }

            if isAutoTitling {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.secondary)
                    .accessibilityLabel("Naming your memo")
            }
        }
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
        EmptyView()
    }

    /// Card background with whisper blue tint
    @ViewBuilder
    private var cardBackground: some View {
        // Use a rectangular base and rely on the outer clipShape
        // to control rounding so middle cards remain square.
        Rectangle()
            .fill(colorScheme == .dark
                  ? Color.semantic(.bgSecondary)
                  : Color.clarityWhite)
            .overlay(
                Rectangle()
                    .fill(colorScheme == .dark
                          ? Color.clear
                          : Color.mauveTint.opacity(0.3))
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

    /// Clip shape that rounds only the exposed corners within a stacked group
    private var groupClipShape: some InsettableShape {
        let r = SonoraDesignSystem.Spacing.cardRadius
        // Single item: round all
        if isFirstInSection && isLastInSection {
            return UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: r, bottomTrailingRadius: r, topTrailingRadius: r)
        }
        // First only: round top corners
        if isFirstInSection {
            return UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: r)
        }
        // Last only: round bottom corners
        if isLastInSection {
            return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: r, bottomTrailingRadius: r, topTrailingRadius: 0)
        }
        // Middle: square corners
        return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0)
    }

    /// Single-pixel hairline thickness based on device scale
    private var hairlineThickness: CGFloat { 1.5 }

    /// Low-contrast separator color that adapts to color scheme
    private var hairlineColor: Color {
        (colorScheme == .dark
         ? Color.semantic(.separator).opacity(0.22)
         : Color.semantic(.separator).opacity(0.14))
    }

    // MARK: - Animation Helpers

    private func configureAnimations() {
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

    private var isAutoTitling: Bool {
        switch titleCoordinator.state(for: memo.id) {
        case .inProgress:
            let show = memo.customTitle == nil || memo.customTitle?.isEmpty == true
            return show
        case .streaming:
            let show = memo.customTitle == nil || memo.customTitle?.isEmpty == true
            return show
        case .success:
            return false
        case .failed:
            return false
        case .idle:
            return false
        }
    }

    private var streamingTitle: String? {
        if case .streaming(let partial) = titleCoordinator.state(for: memo.id) {
            return partial
        }
        return nil
    }

    private var primaryTitleText: String {
        if let streaming = streamingTitle, !streaming.isEmpty {
            return streaming
        }
        return memo.displayName
    }
}
