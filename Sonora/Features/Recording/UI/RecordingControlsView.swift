import SwiftUI

struct RecordingControlsView: View {
    let recordingState: RecordingSessionState
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: SonoraDesignSystem.Spacing.lg) {
            primaryActionButton
            timerSpacer
            stopButton
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: recordingState)
    }

    private var primaryActionButton: some View {
        Button(action: {
            HapticManager.shared.playSelection()
            if recordingState == .recording {
                onPause()
            } else if recordingState == .paused {
                onResume()
            }
        }, label: {
            ZStack {
                Circle()
                    .fill(buttonBackgroundGradient)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )

                if recordingState == .recording {
                    // Active recording pulse - match the button gradient
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.sonoraWarmPink.opacity(0.4),
                                    Color.sonoraMagenta.opacity(0.3),
                                    Color.sonoraPlum.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(1.05)
                        .animation(.easeInOut(duration: 1.5).repeatForever(), value: recordingState)
                }

                Image(systemName: buttonIconName)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.white)
            }
        })
        .buttonStyle(.plain)
        .accessibilityLabel(buttonAccessibilityLabel)
    }

    private var buttonBackgroundGradient: LinearGradient {
        switch recordingState {
        case .recording:
            // Active recording - logo gradient with subtle shift toward purple (hints at "pause")
            return LinearGradient(
                colors: [
                    Color.sonoraWarmPink,     // Warm pink (shifted cooler than main button)
                    Color.sonoraMagenta,      // Rich magenta
                    Color.sonoraPlum          // Deep plum
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .paused:
            // Paused - deepest, coolest logo gradient (contemplative state)
            return LinearGradient(
                colors: [
                    Color.sonoraMagenta,      // Rich magenta
                    Color.sonoraPlum,         // Deep plum
                    Color.sonoraDarkPurple    // Deepest purple
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .idle:
            // Idle - warmest logo gradient (inviting)
            return LinearGradient(
                colors: [
                    Color.sonoraCoral,
                    Color.sonoraWarmPink,
                    Color.sonoraPlum
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var stopButton: some View {
        Button(action: {
            HapticManager.shared.playRecordingFeedback(isStarting: false)
            onStop()
        }, label: {
            ZStack {
                // Stop button with red/warning tones - signals completion/finality
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.sparkOrange,        // Energetic coral/red
                                Color(hexString: "#FF4D6D"),  // Bright red-pink
                                Color.sonoraWarmPink,     // Warm pink
                                Color.sonoraMagenta       // Rich magenta depth
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                Image(systemName: "stop.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }
        })
        .buttonStyle(.plain)
        .accessibilityLabel("Stop and finalize recording")
    }

    private var timerSpacer: some View { Color.clear.frame(height: 8) }

    private var buttonBackgroundColor: Color {
        switch recordingState {
        case .recording: return Color.recordingActive
        case .paused: return Color.semantic(.warning)
        case .idle: return Color.recordingInactive
        }
    }

    private var buttonIconName: String {
        recordingState == .recording ? "pause.fill" : "play.fill"
    }

    private var buttonAccessibilityLabel: String {
        switch recordingState {
        case .recording: return "Pause recording"
        case .paused: return "Resume recording"
        case .idle: return "Start recording"
        }
    }
}
