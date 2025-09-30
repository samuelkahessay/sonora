//
//  SonoraAnimations.swift
//  Sonora
//
//  Comprehensive animation library implementing Sonora brand principles
//  Provides organic, contemplative animations that embody "Clarity through Voice"
//

import SwiftUI

// Minimal animations utility retained for current usage
enum SonoraAnimations {
    /// Check if user prefers reduced motion
    @MainActor static var prefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
}
