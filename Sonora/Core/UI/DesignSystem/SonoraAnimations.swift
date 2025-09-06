//
//  SonoraAnimations.swift
//  Sonora
//
//  Comprehensive animation library implementing Sonora brand principles
//  Provides organic, contemplative animations that embody "Clarity through Voice"
//

import SwiftUI

// MARK: - Sonora Animation System

/// Central animation library for Sonora brand identity
/// Implements organic, contemplative timing and spring physics throughout the app
enum SonoraAnimations {
    
    // MARK: - Core Animation Principles
    
    /// Gentle spring animation for organic, natural movement
    static let gentleSpring = Animation.spring(
        response: 0.6,
        dampingFraction: 0.8,
        blendDuration: 0
    )
    
    /// Organic spring for more pronounced movements
    static let organicSpring = Animation.spring(
        response: 0.8,
        dampingFraction: 0.7,
        blendDuration: 0
    )
    
    /// Contemplative timing for thoughtful moments
    static let contemplative = Animation.easeInOut(duration: 1.2)
    
    /// Quick response for immediate feedback
    static let quickResponse = Animation.easeOut(duration: 0.3)
    
    /// Slow emergence for profound moments
    static let emergence = Animation.easeOut(duration: 0.8)
    
    // MARK: - Brand-Specific Animation Patterns
    
    /// SonicBloom breathing animation - central to brand identity
    static let sonicBloomBreathing = Animation
        .easeInOut(duration: 2.0)
        .repeatForever(autoreverses: true)
    
    /// Crystallization timing for insight revelation
    static let crystallization = Animation.easeInOut(duration: 1.5)
    
    /// Waveform pulse for audio-related elements
    static let waveformPulse = Animation
        .easeInOut(duration: 1.2)
        .repeatForever(autoreverses: true)
    
    /// Text revelation for important moments
    static let textRevelation = Animation.easeOut(duration: 0.8)
    
    /// Card emergence for memo and insight cards
    static let cardEmergence = Animation.spring(
        response: 0.6,
        dampingFraction: 0.8
    )
    
    // MARK: - Interaction Animations
    
    /// Tap response with haptic-like feel
    static let tapResponse = Animation.spring(
        response: 0.2,
        dampingFraction: 0.6
    )
    
    /// Selection animation for multi-select scenarios
    static let selection = Animation.spring(
        response: 0.3,
        dampingFraction: 0.7
    )
    
    /// Navigation transition timing
    static let navigation = Animation.easeInOut(duration: 0.5)
    
    // MARK: - Content Animations
    
    /// List item appearance with staggered timing
    static func listItemAppearance(delay: Double = 0) -> Animation {
        .spring(response: 0.6, dampingFraction: 0.8)
        .delay(delay)
    }
    
    /// Insight hint emergence with contemplative delay
    static let insightHint = Animation.spring(
        response: 0.6,
        dampingFraction: 0.8
    ).delay(0.5)
    
    /// Progress animation for transcription states
    static let progress = Animation.linear(duration: 0.3)
    
    // MARK: - State Transition Animations
    
    /// Recording state changes
    static let recordingState = Animation.spring(
        response: 0.4,
        dampingFraction: 0.75
    )
    
    /// Analysis completion
    static let analysisComplete = Animation.spring(
        response: 0.8,
        dampingFraction: 0.6
    )
    
    /// Error state with gentle attention-getting
    static let errorState = Animation.spring(
        response: 0.5,
        dampingFraction: 0.8
    )
}

// MARK: - Animation Modifiers

extension View {
    
    /// Apply gentle spring animation with Sonora brand timing
    func gentleSpring() -> some View {
        self.animation(SonoraAnimations.gentleSpring, value: UUID())
    }
    
    /// Apply organic spring animation for natural movement
    func organicSpring() -> some View {
        self.animation(SonoraAnimations.organicSpring, value: UUID())
    }
    
    /// Apply contemplative timing for thoughtful moments
    func contemplativeAnimation() -> some View {
        self.animation(SonoraAnimations.contemplative, value: UUID())
    }
    
    /// Apply SonicBloom breathing animation
    func sonicBloomBreathing() -> some View {
        self.animation(SonoraAnimations.sonicBloomBreathing, value: UUID())
    }
    
    /// Apply waveform pulse animation
    func waveformPulse() -> some View {
        self.animation(SonoraAnimations.waveformPulse, value: UUID())
    }
}

// MARK: - Complex Animation Sequences

@MainActor
extension SonoraAnimations {
    
    /// Insight crystallization sequence
    static func crystallizationSequence(
        progress: Binding<Double>,
        textOpacity: Binding<Double>,
        completion: @MainActor @escaping () -> Void = {}
    ) {
        // Phase 1: Crystallization pattern
        withAnimation(.easeInOut(duration: 1.5)) {
            progress.wrappedValue = 1.0
        }
        
        // Phase 2: Text revelation
        withAnimation(.easeOut(duration: 0.8).delay(1.0)) {
            textOpacity.wrappedValue = 1.0
        }
        
        // Completion callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { completion() }
    }
    
    /// Card entrance sequence with staggered timing
    static func cardEntranceSequence<T: Hashable>(
        items: [T],
        scales: Binding<[T: Double]>,
        opacities: Binding<[T: Double]>
    ) {
        for (index, item) in items.enumerated() {
            let delay = Double(index) * 0.1
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                scales.wrappedValue[item] = 1.0
                opacities.wrappedValue[item] = 1.0
            }
        }
    }
    
    /// SonicBloom emergence sequence
    static func sonicBloomEmergence(
        scale: Binding<Double>,
        opacity: Binding<Double>,
        breathingPhase: Binding<Bool>,
        completion: @MainActor @escaping () -> Void = {}
    ) {
        // Phase 1: Initial emergence
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            scale.wrappedValue = 1.0
            opacity.wrappedValue = 1.0
        }
        
        // Phase 2: Begin breathing (with delay)
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
            breathingPhase.wrappedValue = true
        }
        
        // Completion callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { completion() }
    }
}

// MARK: - Animation Timing Functions

extension SonoraAnimations {
    
    /// Custom easing for organic feel
    static func organicEasing(duration: Double) -> Animation {
        .timingCurve(0.25, 0.1, 0.25, 1.0, duration: duration)
    }
    
    /// Breathing rhythm timing
    static func breathingRhythm(duration: Double = 2.0) -> Animation {
        .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
    
    /// Staggered appearance timing
    static func staggered(delay: Double, duration: Double = 0.6) -> Animation {
        .spring(response: duration, dampingFraction: 0.8).delay(delay)
    }
}

// MARK: - Accessibility-Aware Animations

extension SonoraAnimations {
    
    /// Check if user prefers reduced motion
    @MainActor
    static var prefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    /// Reduced motion alternative for gentle spring
    @MainActor
    static var gentleSpringReduced: Animation {
        prefersReducedMotion ? .linear(duration: 0.2) : gentleSpring
    }
    
    /// Reduced motion alternative for organic spring
    @MainActor
    static var organicSpringReduced: Animation {
        prefersReducedMotion ? .linear(duration: 0.3) : organicSpring
    }
    
    /// Reduced motion alternative for breathing animation
    @MainActor
    static var breathingReduced: Animation {
        prefersReducedMotion ? .linear(duration: 0.5) : sonicBloomBreathing
    }
    
    /// Reduced motion alternative for crystallization
    @MainActor
    static var crystallizationReduced: Animation {
        prefersReducedMotion ? .linear(duration: 0.5) : crystallization
    }
}

// MARK: - Animation Utilities

@MainActor
extension View {
    
    /// Apply animation with automatic reduced motion support
    func accessibleAnimation<V: Equatable>(
        _ animation: Animation,
        reducedMotionFallback: Animation,
        value: V
    ) -> some View {
        self.animation(
            SonoraAnimations.prefersReducedMotion ? reducedMotionFallback : animation,
            value: value
        )
    }
    
    /// Apply Sonora brand animation with accessibility support
    func sonoraAnimation<V: Equatable>(
        _ animation: Animation,
        value: V
    ) -> some View {
        let reducedFallback = Animation.linear(duration: 0.3)
        return accessibleAnimation(animation, reducedMotionFallback: reducedFallback, value: value)
    }
}
