//
//  SonoraInsightCard.swift
//  Sonora
//
//  Premium insight card with crystallization animation
//  Implements progressive revelation system for AI-generated insights
//

import SwiftUI

// MARK: - SonoraInsightCard

/// Premium insight card component that reveals AI insights through crystallization animation
///
/// **Design Philosophy:**
/// - Progressive revelation: Crystallization pattern emerges before text
/// - New York serif for profound moments and quotes
/// - Growth Green highlighting for positive insights
/// - Organic animation timing that feels natural and contemplative
///
/// **Brand Integration:**
/// - Embodies "Clarity through Voice" through visual emergence
/// - Uses semantic brand colors for different insight types
/// - Follows SonoraDesignSystem spacing and typography
/// - Implements thoughtful animation delays for contemplative feel
struct SonoraInsightCard: View {
    
    // MARK: - Properties
    
    let insight: InsightData
    let isHighlighted: Bool
    @State private var crystallizationProgress: Double = 0
    @State private var textOpacity: Double = 0
    @State private var cardScale: Double = 0.95
    @State private var glowIntensity: Double = 0
    
    // MARK: - Initialization
    
    init(insight: InsightData, isHighlighted: Bool = false) {
        self.insight = insight
        self.isHighlighted = isHighlighted
    }
    
    // MARK: - View Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.md) {
            // Crystallization background pattern
            crystallizationLayer
            
            // Insight content with progressive revelation
            insightContentSection
            
            // Confidence and category indicators
            metadataSection
        }
        .padding(.all, SonoraDesignSystem.Spacing.breathingRoom)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(cardScale)
        .shadow(
            color: insightColor.opacity(glowIntensity * 0.3),
            radius: 12, x: 0, y: 4
        )
        .onAppear {
            triggerCrystallizationSequence()
        }
    }
    
    // MARK: - View Components
    
    /// Crystallization pattern layer with geometric emergence
    @ViewBuilder
    private var crystallizationLayer: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                drawCrystallinePattern(
                    in: context,
                    size: size,
                    progress: crystallizationProgress
                )
            }
        }
        .frame(height: 40)
        .opacity(crystallizationProgress > 0 ? 1 : 0)
    }
    
    /// Main insight content with thoughtful typography
    @ViewBuilder
    private var insightContentSection: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.sm) {
            // Category indicator
            if !insight.category.isEmpty {
                categoryIndicator
            }
            
            // Main insight text with system serif
            Text(insight.text)
                .font(SonoraDesignSystem.Typography.insightSerif)
                .foregroundColor(insightColor)
                .lineSpacing(4)
                .opacity(textOpacity)
                .multilineTextAlignment(.leading)
        }
    }
    
    /// Metadata section with confidence and additional context
    @ViewBuilder
    private var metadataSection: some View {
        HStack(spacing: SonoraDesignSystem.Spacing.md) {
            // Confidence indicator
            confidenceIndicator
            
            Spacer()
            
            // Insight type or source
            if !insight.source.isEmpty {
                sourceIndicator
            }
        }
        .opacity(textOpacity * 0.8)
    }
    
    /// Category indicator with brand colors
    @ViewBuilder
    private var categoryIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(insightColor)
                .frame(width: 6, height: 6)
            
            Text(insight.category)
                .font(SonoraDesignSystem.Typography.caption)
                .foregroundColor(insightColor)
                .textCase(.uppercase)
        }
        .opacity(textOpacity)
    }
    
    /// Confidence level indicator
    @ViewBuilder
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < confidenceLevel ? insightColor.opacity(0.8) : Color.reflectionGray.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }
    
    /// Source indicator for insight origin
    @ViewBuilder
    private var sourceIndicator: some View {
        Text(insight.source)
            .font(SonoraDesignSystem.Typography.caption)
            .foregroundColor(.reflectionGray)
    }
    
    /// Card background with subtle brand tinting
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.clarityWhite)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(insightBackgroundColor.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(insightColor.opacity(glowIntensity * 0.5), lineWidth: 1)
            )
    }
    
    // MARK: - Computed Properties
    
    /// Primary color for this insight based on type and sentiment
    private var insightColor: Color {
        if isHighlighted {
            return .insightGold
        }
        
        switch insight.category.lowercased() {
        case "growth", "positive", "achievement":
            return .growthGreen
        case "reflection", "wisdom", "learning":
            return .depthPurple
        case "action", "todo", "reminder":
            return .sparkOrange
        default:
            return .insightGold
        }
    }
    
    /// Background color for insight cards
    private var insightBackgroundColor: Color {
        switch insightColor {
        case .growthGreen:
            return .whisperBlue
        case .depthPurple:
            return .whisperBlue.opacity(0.6)
        case .sparkOrange:
            return .whisperBlue.opacity(0.8)
        default:
            return .whisperBlue
        }
    }
    
    /// Confidence level (1-5 dots) based on insight confidence score
    private var confidenceLevel: Int {
        Int((insight.confidence * 5).rounded())
    }
    
    // MARK: - Animation Methods
    
    /// Trigger the complete crystallization sequence
    private func triggerCrystallizationSequence() {
        // Phase 1: Card emergence
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            cardScale = 1.0
        }
        
        // Phase 2: Crystallization pattern (starts after card appears)
        withAnimation(.easeInOut(duration: 1.5).delay(0.2)) {
            crystallizationProgress = 1.0
        }
        
        // Phase 3: Text revelation (starts during crystallization)
        withAnimation(.easeOut(duration: 0.8).delay(1.0)) {
            textOpacity = 1.0
        }
        
        // Phase 4: Subtle glow for highlighted insights
        if isHighlighted {
            withAnimation(.easeInOut(duration: 1.0).delay(1.5)) {
                glowIntensity = 1.0
            }
        }
    }
    
    /// Draw crystalline pattern that emerges over time
    private func drawCrystallinePattern(in context: GraphicsContext, size: CGSize, progress: Double) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let maxRadius = min(size.width, size.height) / 2
        
        // Create crystalline points based on progress
        let pointCount = Int(progress * 8) + 2
        let points = (0..<pointCount).map { i in
            let angle = Double(i) * 2 * .pi / Double(pointCount)
            let radius = maxRadius * (0.3 + 0.7 * progress)
            return CGPoint(
                x: centerX + cos(angle) * radius,
                y: centerY + sin(angle) * radius * 0.3
            )
        }
        
        // Draw connecting lines with opacity based on progress
        for i in 0..<points.count {
            let nextIndex = (i + 1) % points.count
            let path = Path { path in
                path.move(to: points[i])
                path.addLine(to: points[nextIndex])
            }
            
            context.stroke(
                path,
                with: .color(insightColor.opacity(progress * 0.6)),
                lineWidth: 1.0
            )
        }
        
        // Add central connection point
        if progress > 0.5 {
            let centralPath = Path { path in
                path.addEllipse(in: CGRect(
                    x: centerX - 2,
                    y: centerY - 2,
                    width: 4,
                    height: 4
                ))
            }
            
            context.fill(
                centralPath,
                with: .color(insightColor.opacity(progress))
            )
        }
    }
}

// MARK: - Supporting Data Structures

/// Data structure for individual insights
struct InsightData {
    let text: String
    let category: String
    let confidence: Double // 0.0 to 1.0
    let source: String
    let timestamp: Date
    
    init(text: String, category: String = "", confidence: Double = 0.8, source: String = "", timestamp: Date = Date()) {
        self.text = text
        self.category = category
        self.confidence = max(0.0, min(1.0, confidence))
        self.source = source
        self.timestamp = timestamp
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        SonoraInsightCard(
            insight: InsightData(
                text: "Your morning reflections often center around personal growth and setting intentions for the day ahead.",
                category: "Growth",
                confidence: 0.85,
                source: "Pattern Analysis"
            ),
            isHighlighted: true
        )
        
        SonoraInsightCard(
            insight: InsightData(
                text: "Consider scheduling dedicated time for the project planning you mentioned.",
                category: "Action",
                confidence: 0.72,
                source: "Task Detection"
            )
        )
    }
    .padding()
    .background(Color.whisperBlue.opacity(0.3))
}
