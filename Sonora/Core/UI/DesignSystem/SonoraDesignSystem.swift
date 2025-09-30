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

        // Component-specific spacing
        static let cardRadius: CGFloat = 8
        static let iconToTextSpacing: CGFloat = 6
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

        /// Recording timer display (Large title serif, monospaced)
        static let timerDisplay = Font.system(.largeTitle, design: .serif)
            .monospacedDigit()

        // MARK: - UI Elements

        /// Navigation title styling (system serif headline)
        static let navigationTitle = Font(serifUIFont(for: .headline))
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

        /// Breathing animation for calm, meditative elements
        static let breathing = SwiftUI.Animation
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)

        // MARK: - Timing Functions
        // (unused explicit duration constants removed)
    }

    // MARK: - Shadow & Elevation

    // Shadow presets struct/enum removed; keep simple view modifiers below

    // MARK: - Layout Constraints

    /// Layout specifications for consistent component sizing
    enum Layout {

        // Icon sizes
        static let iconExtraLarge: CGFloat = 48

        // Content constraints
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

    // MARK: - Animation Modifiers

    // MARK: - Shadow Modifiers

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
