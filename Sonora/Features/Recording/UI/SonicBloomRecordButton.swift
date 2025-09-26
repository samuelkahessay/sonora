//
//  SonicBloomRecordButton.swift
//  Sonora
//
//  The signature "Sonic Bloom" recording button - transforms from organic waveform
//  to structured geometric patterns, embodying "Clarity through Voice"
//

import SwiftUI

// MARK: - Sonic Bloom Record Button

/// The centerpiece recording button that embodies Sonora's brand identity
/// Features organic waveform animation that transforms into geometric patterns during recording
struct SonicBloomRecordButton: View {
    
    // Progress (0...1) to display an outer ring during recording
    var progress: Double? = nil
    
    // MARK: - Properties
    
    let isRecording: Bool
    let action: () -> Void
    
    // Animation state
    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    @State private var isAnimating: Bool = false
    @State private var bloomScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.0
    @State private var bloomEvent: BloomEvent = BloomEvent(id: UUID(), style: .expand)
    
    // Constants
    private let buttonSize: CGFloat = 180
    private let waveformCount: Int = 8
    private let bloomAnimationDuration: TimeInterval = 0.8
    
    var body: some View {
        Button(action: {
            performAction()
        }) {
            ZStack {
                // Outer pulse ring (appears during recording)
                pulseRing
                
                // Main button background with gradient
                mainButtonBackground
                
                // Waveform bloom pattern
                waveformBloom
                
                // Central icon with smooth transitions
                centerIcon
                
                // Inner geometric pattern (appears during recording)
                innerGeometry
            }
            .frame(width: buttonSize, height: buttonSize)
            .scaleEffect(bloomScale)
        }
        .buttonStyle(PlainButtonStyle())
        .bloomPulse(event: $bloomEvent)
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
        .onChange(of: isRecording) { _, started in
            animateRecordingState(started)
            if started {
                bloomEvent = BloomEvent(id: UUID(), style: .expand)
            } else {
                bloomEvent = BloomEvent(id: UUID(), style: .collapse)
            }
        }
        .onAppear {
            // Start value-driven animations tied to a single trigger
            isAnimating = true
        }
        .onDisappear {
            // Stop animations to save battery when off-screen
            isAnimating = false
        }
    }
    
    // MARK: - Button Components
    

    @ViewBuilder
    private var pulseRing: some View {
        if isRecording {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.recordingActive.opacity(pulseOpacity),
                            Color.recordingActive.opacity(pulseOpacity * 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: buttonSize + 40, height: buttonSize + 40)
                .opacity(pulseOpacity)
                .animation(SonoraDesignSystem.Animation.breathing, value: pulseOpacity)
        }
    }
    
    /// Main button background with brand gradient
    private var mainButtonBackground: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        isRecording ? Color.recordingActive : Color.recordingInactive.opacity(0.8),
                        isRecording ? Color.recordingActive.opacity(0.8) : Color.recordingInactive.opacity(0.6)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: buttonSize * 0.6
                )
            )
            .overlay(
                Circle()
                    .stroke(
                        Color.clarityWhite.opacity(isRecording ? 0.3 : 0.1),
                        lineWidth: 2
                    )
            )
            .brandShadow()
    }
    
    /// Organic waveform pattern that transforms during recording (time-driven)
    private var waveformBloom: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let rotationDeg: Double = reduceMotion ? 0 : (t.truncatingRemainder(dividingBy: 20.0) / 20.0) * 360.0
            let phase: CGFloat = reduceMotion ? 0 : CGFloat((t.truncatingRemainder(dividingBy: 3.0) / 3.0) * 2.0 * .pi)

            ZStack {
                ForEach(0..<waveformCount, id: \.self) { index in
                    WaveformPetal(
                        angle: Double(index) * (360.0 / Double(waveformCount)),
                        phase: phase,
                        isActive: isRecording,
                        petalIndex: index
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clarityWhite.opacity(isRecording ? 0.9 : 0.6),
                                Color.clarityWhite.opacity(isRecording ? 0.4 : 0.2)
                            ],
                            startPoint: .center,
                            endPoint: .trailing
                        )
                    )
                    .blendMode(isRecording ? .overlay : .normal)
                }
            }
            .rotationEffect(.degrees(rotationDeg))
            .opacity(isRecording ? 1.0 : 0.7)
        }
    }
    
    /// Center icon with smooth state transitions
    private var centerIcon: some View {
        ZStack {
            // Recording state: Stop icon
            if isRecording {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.textOnColored)
                    .frame(width: 28, height: 28)
                    .transition(.scale.combined(with: .opacity))
            } else {
                // Idle state: Microphone icon with subtle pulse
                Image(systemName: "mic.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(Color.textOnColored)
                    .scaleEffect(reduceMotion ? 1.0 : (isAnimating ? 1.05 : 1.0))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(SonoraDesignSystem.Animation.bloomTransition, value: isRecording)
        .animation(
            reduceMotion ? .default : SonoraDesignSystem.Animation.breathing,
            value: isAnimating
        )
    }
    
    /// Inner geometric pattern that emerges during recording
    @ViewBuilder
    private var innerGeometry: some View {
        if isRecording {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                // Half the outer rotation rate: 180 degrees per 20s
                let innerRotation: Double = reduceMotion ? 0 : (t.truncatingRemainder(dividingBy: 20.0) / 20.0) * 180.0

                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.clear)
                            .frame(width: 60, height: 2)
                            .offset(y: -20)
                            .rotationEffect(.degrees(Double(index) * 60))
                    }
                }
                .rotationEffect(.degrees(innerRotation))
                .transition(.scale.combined(with: .opacity))
            }
            .animation(SonoraDesignSystem.Animation.gentleSpring.delay(0.2), value: isRecording)
        }
    }
    
    // MARK: - Animation Logic
    
    /// Perform the button action with haptic feedback
    private func performAction() {
        // Immediate visual feedback
        withAnimation(SonoraDesignSystem.Animation.quickFeedback) {
            bloomScale = 0.95
        }
        
        // Spring back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(SonoraDesignSystem.Animation.energeticSpring) {
                bloomScale = 1.0
            }
        }
        
        // Execute the action
        action()
    }
    
    /// Animate the recording state transition
    private func animateRecordingState(_ recording: Bool) {
        withAnimation(SonoraDesignSystem.Animation.bloomTransition) {
            // Scale slightly larger when recording for prominence
            bloomScale = recording ? 1.05 : 1.0
        }
        
        if recording {
            // Start recording animations
            withAnimation(SonoraDesignSystem.Animation.breathing) {
                pulseOpacity = 0.6
            }
        } else {
            // Stop recording animations
            withAnimation(SonoraDesignSystem.Animation.gentleSpring) {
                pulseOpacity = 0.0
            }
        }
    }
    
    // No manual frame loop; animations are value-driven and display-synced
}

// MARK: - Waveform Petal Shape

/// Individual petal shape that forms the waveform bloom pattern
struct WaveformPetal: Shape {
    let angle: Double
    var phase: CGFloat // animatable
    let isActive: Bool
    let petalIndex: Int
    
    // Animate smoothly by exposing `phase` as animatable data
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Constrain petals to remain within the main background circle.
        // The main button background is a Circle() that fills the full frame,
        // so its radius is half of the rect's width/height.
        let R = min(rect.width, rect.height) / 2.0
        let margin: CGFloat = 4 // keep a small visual gap to ensure petals never exceed the circle

        // Calculate organic waveform amplitude (smaller factors so tips stay inside R)
        let baseAmplitude: CGFloat = isActive ? 0.08 : 0.05
        let waveVariation = sin(phase + CGFloat(petalIndex) * 0.5) * 0.4 // -0.4...+0.4
        let waveAmplitude = baseAmplitude * (1 + waveVariation) // ~0.048...0.112 when active

        // Petal radial bounds as a proportion of the main circle radius
        let baseStartFactor: CGFloat = 0.62
        let baseEndFactor: CGFloat = 0.82

        var startRadius = R * (baseStartFactor + waveAmplitude)
        var endRadius = R * (baseEndFactor + waveAmplitude * 1.5)

        // Hard clamp to ensure petal tips never exceed the circle radius
        startRadius = min(startRadius, R - margin * 2)
        endRadius = min(endRadius, R - margin)

        let petalWidth: CGFloat = isActive ? 25 : 15

        // Start point
        let startAngle = Angle.degrees(angle - Double(petalWidth) / 2)
        let endAngle = Angle.degrees(angle + Double(petalWidth) / 2)
        
        let startPoint = CGPoint(
            x: center.x + cos(startAngle.radians) * startRadius,
            y: center.y + sin(startAngle.radians) * startRadius
        )
        
        let endPoint = CGPoint(
            x: center.x + cos(endAngle.radians) * startRadius,
            y: center.y + sin(endAngle.radians) * startRadius
        )
        
        let tipPoint = CGPoint(
            x: center.x + cos(Angle.degrees(angle).radians) * endRadius,
            y: center.y + sin(Angle.degrees(angle).radians) * endRadius
        )
        
        // Create curved petal shape (break into simpler sub-expressions for type-checker)
        path.move(to: startPoint)
        let midRadius = (startRadius + endRadius) / 2
        let ctrl1 = CGPoint(
            x: center.x + cos(startAngle.radians) * midRadius,
            y: center.y + sin(startAngle.radians) * midRadius
        )
        let ctrl2 = CGPoint(
            x: center.x + cos(endAngle.radians) * midRadius,
            y: center.y + sin(endAngle.radians) * midRadius
        )
        path.addQuadCurve(to: tipPoint, control: ctrl1)
        path.addQuadCurve(to: endPoint, control: ctrl2)
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Accessibility Support

extension SonicBloomRecordButton {
    
    /// Accessibility label based on current state
    var accessibilityLabel: String {
        isRecording ? "Stop recording voice memo" : "Start recording voice memo"
    }
    
    /// Accessibility hint for user guidance
    var accessibilityHint: String {
        isRecording 
        ? "Double tap to stop the current recording and save your voice memo"
        : "Double tap to begin recording a voice memo"
    }
    
    /// Apply accessibility modifiers
    func accessibilityConfiguration() -> some View {
        self
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(isRecording ? [.startsMediaSession] : [.startsMediaSession])
            .accessibilityRemoveTraits(isRecording ? [] : [.isSelected])
    }
}
