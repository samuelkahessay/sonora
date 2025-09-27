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
        }) {
            ZStack {
                Circle()
                    .fill(buttonBackgroundColor)
                    .frame(width: 120, height: 120)

                if recordingState == .recording {
                    Circle()
                        .stroke(Color.recordingActive.opacity(0.3), lineWidth: 3)
                        .frame(width: 140, height: 140)
                        .scaleEffect(1.05)
                        .animation(.easeInOut(duration: 1.5).repeatForever(), value: recordingState)
                }

                Image(systemName: buttonIconName)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(buttonAccessibilityLabel)
    }

    private var stopButton: some View {
        Button(action: {
            HapticManager.shared.playRecordingFeedback(isStarting: false)
            onStop()
        }) {
            ZStack {
                Circle()
                    .fill(Color.semantic(.error))
                    .frame(width: 80, height: 80)
                Image(systemName: "stop.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }
        }
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
