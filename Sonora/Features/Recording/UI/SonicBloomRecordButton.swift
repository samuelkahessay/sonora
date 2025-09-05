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
    
    // MARK: - Properties
    
    let isRecording: Bool
    let action: () -> Void
    
    // Animation state
    @State private var waveformPhase: CGFloat = 0
    @State private var bloomScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.0
    @State private var innerRotation: Double = 0
    
    // Constants
    private let buttonSize: CGFloat = SonoraDesignSystem.Spacing.recordButtonSize
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
        .sensoryFeedback(.impact(.medium), trigger: isRecording)
        .onChange(of: isRecording) { _, newValue in
            animateRecordingState(newValue)
        }
        .onAppear {
            startContinuousAnimations()
        }
    }
    
    // MARK: - Button Components
    
    /// Outer pulsing ring that appears during recording
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
    
    /// Organic waveform pattern that transforms during recording
    private var waveformBloom: some View {
        ZStack {
            ForEach(0..<waveformCount, id: \.self) { index in
                WaveformPetal(
                    angle: Double(index) * (360.0 / Double(waveformCount)),
                    phase: waveformPhase,
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
        .rotationEffect(.degrees(innerRotation))
        .opacity(isRecording ? 1.0 : 0.7)
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
                    .scaleEffect(1.0 + sin(waveformPhase * 0.5) * 0.05) // Subtle breathing
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(SonoraDesignSystem.Animation.bloomTransition, value: isRecording)
    }
    
    /// Inner geometric pattern that emerges during recording
    @ViewBuilder
    private var innerGeometry: some View {
        if isRecording {
            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.insightHighlight.opacity(0.3))
                        .frame(width: 60, height: 2)
                        .offset(y: -20)
                        .rotationEffect(.degrees(Double(index) * 60 + innerRotation * 0.5))
                }
            }
            .transition(.scale.combined(with: .opacity))
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
    
    /// Start continuous background animations
    private func startContinuousAnimations() {
        // Continuous waveform phase animation
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            waveformPhase += 0.02
            if waveformPhase > .pi * 2 {
                waveformPhase = 0
            }
        }
        
        // Continuous inner rotation
        withAnimation(
            Animation.linear(duration: 20.0).repeatForever(autoreverses: false)
        ) {
            innerRotation = 360
        }
    }
}

// MARK: - Waveform Petal Shape

/// Individual petal shape that forms the waveform bloom pattern
struct WaveformPetal: Shape {
    let angle: Double
    let phase: CGFloat
    let isActive: Bool
    let petalIndex: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width * 0.35
        
        // Calculate organic waveform amplitude
        let baseAmplitude: CGFloat = isActive ? 0.3 : 0.15
        let waveAmplitude = baseAmplitude * (1 + sin(phase + CGFloat(petalIndex) * 0.5) * 0.4)
        
        // Create organic petal shape
        let startRadius = radius * (0.7 + waveAmplitude)
        let endRadius = radius * (1.0 + waveAmplitude * 1.5)
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
        
        // Create curved petal shape
        path.move(to: startPoint)
        path.addQuadCurve(to: tipPoint, control: CGPoint(
            x: center.x + cos(startAngle.radians) * (startRadius + endRadius) / 2,
            y: center.y + sin(startAngle.radians) * (startRadius + endRadius) / 2
        ))
        path.addQuadCurve(to: endPoint, control: CGPoint(
            x: center.x + cos(endAngle.radians) * (startRadius + endRadius) / 2,
            y: center.y + sin(endAngle.radians) * (startRadius + endRadius) / 2
        ))
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
        : "Double tap to begin recording a voice memo for up to 60 seconds"
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

// MARK: - Preview Support

#if DEBUG
struct SonicBloomRecordButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 60) {
            // Idle state
            SonicBloomRecordButton(isRecording: false) {
                print("Start recording")
            }
            .accessibilityConfiguration()
            
            // Recording state
            SonicBloomRecordButton(isRecording: true) {
                print("Stop recording")
            }
            .accessibilityConfiguration()
        }
        .padding(60)
        .background(
            LinearGradient(
                colors: [Color.whisperBlue, Color.clarityWhite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .previewDisplayName("Sonic Bloom Record Button")
        .previewLayout(.sizeThatFits)
    }
}
#endif