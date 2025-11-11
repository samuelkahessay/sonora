//
//  SonoraLaunchView.swift
//  Sonora
//
//  Premium launch experience with SonicBloom breathing animation
//  Creates first impression of "Clarity through Voice" brand identity
//

import SwiftUI

// MARK: - SonoraLaunchView

/// Premium launch view that embodies the Sonora brand identity from first interaction
///
/// **Design Philosophy:**
/// - SonicBloom breathing animation as the central focal point
/// - Gentle waveform readiness indicator for organic feel
/// - Smooth transition sequence from brand moment to functional interface
/// - Contemplative timing that respects user's mental preparation
///
/// **Brand Integration:**
/// - Uses Insight Gold for premium warmth and recognition
/// - Whisper Blue background for calm, spacious feeling
/// - New York serif for special brand moments
/// - Organic spring animations throughout sequence
struct SonoraLaunchView: View {

    // MARK: - Properties

    @Binding var isLaunching: Bool
    let onLaunchComplete: () -> Void

    @State private var sonicBloomScale: Double = 0.8
    @State private var sonicBloomOpacity: Double = 0
    @State private var breathingPhase: Bool = false
    @State private var waveformAnimation: Bool = false
    @State private var brandTextOpacity: Double = 0
    @State private var readinessIndicatorOpacity: Double = 0
    @State private var backgroundGradientPhase: Bool = false

    // MARK: - View Body

    var body: some View {
        ZStack {
            // Dynamic background with gentle gradient animation
            backgroundGradient

            // Central SonicBloom with breathing animation
            sonicBloomCenterpiece

            // Brand text with elegant typography
            brandTextSection

            // Subtle readiness indicator
            readinessIndicator
        }
        .onAppear {
            triggerLaunchSequence()
        }
    }

    // MARK: - View Components

    /// Dynamic background gradient with gentle animation
    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.sonoraMauve.opacity(backgroundGradientPhase ? 0.15 : 0.25),
                Color.clarityWhite,
                Color.sonoraMauve.opacity(backgroundGradientPhase ? 0.1 : 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: backgroundGradientPhase)
    }

    /// Central SonicBloom logo with breathing animation
    @ViewBuilder
    private var sonicBloomCenterpiece: some View {
        ZStack {
            // Outer breathing rings
            ForEach(0..<3, id: \.self) { ringIndex in
                Circle()
                    .stroke(
                        Color.insightGold.opacity(0.3 - Double(ringIndex) * 0.1),
                        lineWidth: 2
                    )
                    .frame(width: 160 + Double(ringIndex) * 40)
                    .scaleEffect(breathingPhase ? 1.1 + Double(ringIndex) * 0.1 : 1.0)
                    .opacity(breathingPhase ? 0.2 : 0.6)
            }

            // Central waveform icon
            sonicBloomIcon
        }
        .scaleEffect(sonicBloomScale)
        .opacity(sonicBloomOpacity)
    }

    /// Core SonicBloom icon with subtle animation
    @ViewBuilder
    private var sonicBloomIcon: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.insightGold.opacity(0.15))
                .frame(width: 120, height: 120)

            // Waveform symbol with organic animation
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(.insightGold)
                .symbolEffect(.pulse.byLayer)
                .scaleEffect(waveformAnimation ? 1.05 : 1.0)
        }
    }

    /// Brand text with system serif typography
    @ViewBuilder
    private var brandTextSection: some View {
        VStack(spacing: SonoraDesignSystem.Spacing.sm) {
            Text("Sonora")
                .font(.system(.largeTitle, design: .serif))
                .fontWeight(.medium)
                .foregroundColor(.textPrimary)

            Text("Clarity through Voice")
                .font(.system(.subheadline, design: .serif))
                .foregroundColor(.sonoraMauve.opacity(0.7))
                .italic()
        }
        .opacity(brandTextOpacity)
        .offset(y: 140)
    }

    /// Subtle readiness indicator
    @ViewBuilder
    private var readinessIndicator: some View {
        VStack(spacing: SonoraDesignSystem.Spacing.xs) {
            // Animated dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.insightGold.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .opacity(waveformAnimation ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: waveformAnimation
                        )
                }
            }

            Text("Preparing your voice experience")
                .font(SonoraDesignSystem.Typography.caption)
                .foregroundColor(.secondary)
        }
        .opacity(readinessIndicatorOpacity)
        .offset(y: 220)
    }

    // MARK: - Animation Sequence

    /// Trigger the complete launch animation sequence
    private func triggerLaunchSequence() {
        // Phase 1: Initial appearance (0-0.5s)
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            sonicBloomScale = 1.0
            sonicBloomOpacity = 1.0
        }

        // Phase 2: Breathing activation (0.3s delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathingPhase = true
            }

            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                waveformAnimation = true
            }
        }

        // Phase 3: Brand text revelation (0.8s delay)
        withAnimation(.easeOut(duration: 1.0).delay(0.8)) {
            brandTextOpacity = 1.0
        }

        // Phase 4: Readiness indicator (1.2s delay)
        withAnimation(.easeOut(duration: 0.8).delay(1.2)) {
            readinessIndicatorOpacity = 1.0
        }

        // Phase 5: Background gradient animation (1.0s delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            backgroundGradientPhase = true
        }

        // Phase 6: Launch completion (2.5s total duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            completeLaunchSequence()
        }
    }

    /// Complete the launch sequence with smooth transition
    private func completeLaunchSequence() {
        // Fade out animation
        withAnimation(.easeOut(duration: 0.6)) {
            sonicBloomOpacity = 0
            brandTextOpacity = 0
            readinessIndicatorOpacity = 0
        }

        // Call completion handler after fade completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isLaunching = false
            onLaunchComplete()
        }
    }
}

// MARK: - Preview

#Preview {
    SonoraLaunchView(
        isLaunching: .constant(true)
    ) {
        print("Launch completed")
    }
}
