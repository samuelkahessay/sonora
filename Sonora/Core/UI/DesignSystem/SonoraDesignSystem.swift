//
//  SonoraDesignSystem.swift
//  Sonora
//
//  Comprehensive design system implementing "Purposeful Minimalism"
//  Creates consistent spacing, typography, and animations across the app
//

import SwiftUI
import UIKit

// MARK: - Design System Foundation

/// Central design system for Sonora implementing brand identity principles
enum SonoraDesignSystem {
    
    // MARK: - Spacing System
    
    /// Spacing values based on 8pt grid system for consistent layout rhythm
    enum Spacing {
        /// Breathing room - minimum margins for mental calm (24pt)
        static let breathingRoom: CGFloat = 24
        
        /// Base grid unit for all spacing calculations
        static let gridUnit: CGFloat = 8
        
        /// Extra small spacing (4pt)
        static let xs: CGFloat = 4
        
        /// Small spacing (8pt)
        static let sm: CGFloat = 8
        
        /// Medium spacing (16pt)
        static let md: CGFloat = 16
        
        /// Large spacing (24pt)
        static let lg: CGFloat = 24
        
        /// Extra large spacing (32pt)
        static let xl: CGFloat = 32
        
        /// Extra extra large spacing (48pt)
        static let xxl: CGFloat = 48
        
        /// Massive spacing for hero sections (64pt)
        static let massive: CGFloat = 64
        
        // Component-specific spacing
        static let cardRadius: CGFloat = 8
        static let waveformHeight: CGFloat = 120
        static let recordButtonSize: CGFloat = 160
        static let iconToTextSpacing: CGFloat = 6
        static let sectionSpacing: CGFloat = 32
    }
    
    // MARK: - Typography System
    
    /// Typography hierarchy following brand guidelines with SF Pro and system serif
    enum Typography {
        // MARK: - System Serif Resolution (UIKit → SwiftUI)
        /// Resolve a preferred UIKit serif font for a text style, preserving Dynamic Type
        private static func serifUIFont(for textStyle: UIFont.TextStyle) -> UIFont {
            let base = UIFont.preferredFont(forTextStyle: textStyle)
            if let serifDesc = base.fontDescriptor.withDesign(.serif) {
                return UIFont(descriptor: serifDesc, size: base.pointSize)
            }
            return base
        }
        
        // MARK: - Heading Hierarchy
        
        /// H1: Large title for primary headings (system largeTitle serif)
        static let headingLarge = Font.system(.largeTitle, design: .serif)
            .leading(.tight)
        
        /// H2: Medium title for section headings (system title2 serif)
        static let headingMedium = Font.system(.title2, design: .serif)
            .leading(.tight)
        
        /// H3: Small title for subsections (system title3 serif)
        static let headingSmall = Font.system(.title3, design: .serif)
            .leading(.tight)
        
        // MARK: - Body Text
        
        /// Large body text for important content (system body serif)
        static let bodyLarge = Font.system(.body, design: .serif)
            .leading(.loose)
        
        /// Regular body text for standard content (15pt, Weight 400)
        static let bodyRegular = Font.system(size: 15, weight: .regular, design: .default)
            .leading(.loose)
        
        /// Small body text for secondary content (13pt, Weight 400)
        static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
            .leading(.standard)
        
        /// Caption text for metadata and labels (12pt, Weight 400)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
            .leading(.standard)
        
        // MARK: - Special Typography
        
        /// Serif font for quotes and emotional moments (system serif)
        static let insightSerif = Font.system(.body, design: .serif)
            .leading(.loose)
        
        /// Monospaced digits for time display and metrics
        static let monospaced = Font.system(.body, design: .monospaced)
            .monospacedDigit()
        
        /// Recording timer display (Large title serif, monospaced)
        static let timerDisplay = Font.system(.largeTitle, design: .serif)
            .monospacedDigit()
        
        // MARK: - UI Elements
        
        /// Button text styling
        static let button = Font.system(size: 16, weight: .medium, design: .default)
        
        /// Navigation title styling (system serif headline)
        static let navigationTitle = Font(serifUIFont(for: .headline))
        
        /// Tab bar item styling
        static let tabBarItem = Font.system(size: 10, weight: .medium, design: .default)
    }
    
    // MARK: - Animation System
    
    /// Animation definitions following organic, purposeful movement principles
    enum Animation {
        
        // MARK: - Core Animations
        
        /// Bloom transition for recording state changes
        static let bloomTransition = SwiftUI.Animation.spring(
            response: 0.8,
            dampingFraction: 0.7,
            blendDuration: 0.2
        )
        
        /// Gentle spring for subtle interactions
        static let gentleSpring = SwiftUI.Animation.spring(
            response: 0.6,
            dampingFraction: 0.8,
            blendDuration: 0.1
        )
        
        /// Energetic spring for prominent actions
        static let energeticSpring = SwiftUI.Animation.spring(
            response: 0.3,
            dampingFraction: 0.6,
            blendDuration: 0.1
        )
        
        /// Smooth ease for content reveals
        static let reveal = SwiftUI.Animation.easeOut(duration: 0.6)
        
        /// Quick ease for immediate feedback
        static let quickFeedback = SwiftUI.Animation.easeInOut(duration: 0.25)
        
        /// Waveform pulse animation for recording visualization
        static let waveformPulse = SwiftUI.Animation
            .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: true)
        
        /// Breathing animation for calm, meditative elements
        static let breathing = SwiftUI.Animation
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        
        // MARK: - Timing Functions
        
        /// Duration for quick micro-interactions
        static let microDuration: TimeInterval = 0.15
        
        /// Duration for standard transitions
        static let standardDuration: TimeInterval = 0.3
        
        /// Duration for complex state changes
        static let complexDuration: TimeInterval = 0.6
        
        /// Duration for dramatic reveals
        static let dramaticDuration: TimeInterval = 1.0
    }
    
    // MARK: - Shadow & Elevation
    
    /// Shadow definitions for creating subtle depth
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }
        
        func apply(to view: some View) -> some View {
            view.shadow(color: color, radius: radius, x: x, y: y)
        }
    }
    
    /// Preset shadow styles
    enum Shadows {
        /// Gentle shadow for floating elements
        static let gentle = Shadow(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )
        
        /// Medium shadow for elevated cards
        static let medium = Shadow(
            color: Color.black.opacity(0.12),
            radius: 12,
            x: 0,
            y: 4
        )
        
        /// Strong shadow for prominent elements
        static let strong = Shadow(
            color: Color.black.opacity(0.16),
            radius: 16,
            x: 0,
            y: 6
        )
        
        /// Recording button shadow with brand warmth
        static let recordButton = Shadow(
            color: Color.insightGold.opacity(0.25),
            radius: 12,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Layout Constraints
    
    /// Layout specifications for consistent component sizing
    enum Layout {
        
        // Button dimensions
        static let buttonHeight: CGFloat = 44
        static let buttonMinWidth: CGFloat = 88
        static let largeButtonHeight: CGFloat = 56
        
        // Card dimensions
        static let cardMinHeight: CGFloat = 80
        static let cardMaxWidth: CGFloat = 400
        
        // List and grid
        static let listRowHeight: CGFloat = 72
        static let gridItemSpacing: CGFloat = 16
        
        // Icon sizes
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 24
        static let iconLarge: CGFloat = 32
        static let iconExtraLarge: CGFloat = 48
        
        // Content constraints
        static let maxContentWidth: CGFloat = 600
        static let minTouchTarget: CGFloat = 44
    }
}

// MARK: - View Modifiers

extension View {
    
    // MARK: - Spacing Modifiers
    
    /// Apply standard breathing room padding
    func breathingRoom() -> some View {
        self.padding(SonoraDesignSystem.Spacing.breathingRoom)
    }
    
    /// Apply grid-based padding
    func gridPadding(_ multiplier: CGFloat = 1) -> some View {
        self.padding(SonoraDesignSystem.Spacing.gridUnit * multiplier)
    }
    
    // MARK: - Typography Modifiers
    
    /// Apply heading style with proper line height
    func headingStyle(_ level: HeadingLevel) -> some View {
        self.font(level.font)
            .foregroundColor(.textPrimary)
    }
    
    /// Apply body text style
    func bodyStyle(_ size: BodySize = .regular) -> some View {
        self.font(size.font)
            .foregroundColor(.textPrimary)
            .lineSpacing(2)
    }
    
    /// Apply monospaced styling for numbers and time
    func monospacedStyle() -> some View {
        self.font(SonoraDesignSystem.Typography.monospaced)
            .monospacedDigit()
    }
    
    /// Apply serif styling for special moments
    func serifStyle() -> some View {
        self.font(SonoraDesignSystem.Typography.insightSerif)
            .foregroundColor(.wisdomText)
    }
    
    // MARK: - Animation Modifiers
    
    /// Apply bloom animation with value binding
    func bloomAnimation<V: Equatable>(value: V) -> some View {
        self.animation(SonoraDesignSystem.Animation.bloomTransition, value: value)
    }
    
    /// Apply gentle interaction animation
    func gentleAnimation<V: Equatable>(value: V) -> some View {
        self.animation(SonoraDesignSystem.Animation.gentleSpring, value: value)
    }
    
    /// Apply energetic feedback animation
    func energeticAnimation<V: Equatable>(value: V) -> some View {
        self.animation(SonoraDesignSystem.Animation.energeticSpring, value: value)
    }
    
    // MARK: - Shadow Modifiers
    
    /// Apply gentle shadow for subtle elevation
    func gentleShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )
    }
    
    /// Apply medium shadow for card elevation
    func cardShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.12),
            radius: 12,
            x: 0,
            y: 4
        )
    }
    
    /// Apply brand-specific shadow with golden tint
    func brandShadow() -> some View {
        self.shadow(
            color: Color.insightGold.opacity(0.25),
            radius: 12,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Layout Modifiers
    
    /// Apply standard card styling
    func cardStyle() -> some View {
        self
            .background(Color.backgroundElevated)
            .cornerRadius(SonoraDesignSystem.Spacing.cardRadius)
            .cardShadow()
    }
    
    /// Apply maximum content width constraint
    func maxContentWidth() -> some View {
        self.frame(maxWidth: SonoraDesignSystem.Layout.maxContentWidth)
    }
    
    /// Apply minimum touch target size
    func minTouchTarget() -> some View {
        self.frame(
            minWidth: SonoraDesignSystem.Layout.minTouchTarget,
            minHeight: SonoraDesignSystem.Layout.minTouchTarget
        )
    }
}

// MARK: - Supporting Types

enum HeadingLevel {
    case large, medium, small
    
    var font: Font {
        switch self {
        case .large: return SonoraDesignSystem.Typography.headingLarge
        case .medium: return SonoraDesignSystem.Typography.headingMedium
        case .small: return SonoraDesignSystem.Typography.headingSmall
        }
    }
}

enum BodySize {
    case large, regular, small, caption
    
    var font: Font {
        switch self {
        case .large: return SonoraDesignSystem.Typography.bodyLarge
        case .regular: return SonoraDesignSystem.Typography.bodyRegular
        case .small: return SonoraDesignSystem.Typography.bodySmall
        case .caption: return SonoraDesignSystem.Typography.caption
        }
    }
}

// (Removed duplicate Shadow helper; presets are under SonoraDesignSystem.Shadows)

// MARK: - Preview Support

#if DEBUG
struct SonoraDesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: SonoraDesignSystem.Spacing.xl) {
                typographySection
                spacingSection
                colorSection
                shadowSection
            }
            .breathingRoom()
        }
        .background(Color.backgroundPrimary)
        .previewDisplayName("Sonora Design System")
    }
    
    static var typographySection: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.md) {
            Text("Typography")
                .headingStyle(.medium)
            
            VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.sm) {
                Text("Heading Large")
                    .headingStyle(.large)
                
                Text("Heading Medium")
                    .headingStyle(.medium)
                
                Text("Heading Small")
                    .headingStyle(.small)
                
                Text("Body Large - Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
                    .bodyStyle(.large)
                
                Text("Body Regular - Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
                    .bodyStyle(.regular)
                
                Text("Body Small - Lorem ipsum dolor sit amet.")
                    .bodyStyle(.small)
                
                Text("Caption text")
                    .bodyStyle(.caption)
                
                Text("\"Wisdom flows through mindful listening.\"")
                    .serifStyle()
                
                Text("12:34:56")
                    .monospacedStyle()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    static var spacingSection: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.md) {
            Text("Spacing System")
                .headingStyle(.medium)
            
            VStack(spacing: SonoraDesignSystem.Spacing.xs) {
                spacingExample("Breathing Room", SonoraDesignSystem.Spacing.breathingRoom)
                spacingExample("Extra Large", SonoraDesignSystem.Spacing.xl)
                spacingExample("Large", SonoraDesignSystem.Spacing.lg)
                spacingExample("Medium", SonoraDesignSystem.Spacing.md)
                spacingExample("Small", SonoraDesignSystem.Spacing.sm)
                spacingExample("Extra Small", SonoraDesignSystem.Spacing.xs)
            }
        }
    }
    
    static func spacingExample(_ name: String, _ size: CGFloat) -> some View {
        HStack {
            Rectangle()
                .fill(Color.insightGold)
                .frame(width: size, height: 20)
            Text("\(name) - \(Int(size))pt")
                .bodyStyle(.small)
            Spacer()
        }
    }
    
    static var colorSection: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.md) {
            Text("Brand Colors")
                .headingStyle(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                colorSwatch("Primary", Color.brandPrimary)
                colorSwatch("Secondary", Color.brandSecondary)
                colorSwatch("Accent", Color.sparkOrange)
                colorSwatch("Recording", Color.recordingActive)
                colorSwatch("Insight", Color.insightHighlight)
                colorSwatch("Success", Color.successState)
            }
        }
    }
    
    static func colorSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(height: 40)
            
            Text(name)
                .bodyStyle(.caption)
        }
    }
    
    static var shadowSection: some View {
        VStack(alignment: .leading, spacing: SonoraDesignSystem.Spacing.md) {
            Text("Shadows")
                .headingStyle(.medium)
            
            HStack(spacing: SonoraDesignSystem.Spacing.lg) {
                shadowExample("Gentle") { view in AnyView(view.gentleShadow()) }
                shadowExample("Card") { view in AnyView(view.cardShadow()) }
                shadowExample("Brand") { view in AnyView(view.brandShadow()) }
            }
        }
    }
    
    static func shadowExample(_ name: String, _ modifier: @escaping (AnyView) -> some View) -> some View {
        VStack(spacing: 8) {
            modifier(
                AnyView(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.backgroundElevated)
                        .frame(width: 60, height: 40)
                )
            )
            
            Text(name)
                .bodyStyle(.caption)
        }
    }
}
#endif
