import SwiftUI

struct TranscriptionStatusView: View {
    let state: TranscriptionState
    let compact: Bool
    
    init(state: TranscriptionState, compact: Bool = false) {
        self.state = state
        self.compact = compact
    }
    
    var body: some View {
        HStack(spacing: compact ? 4 : 8) {
            if state.isInProgress {
                LoadingIndicator(size: compact ? .small : .regular)
                    .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)
            } else {
                Image(systemName: state.iconName)
                    .foregroundColor(colorForState(state))
                    .font(compact ? .body : .title3)
                    .fontWeight(.medium)
                    .accessibilityLabel(state.statusText)
            }
            
            if !compact {
                Text(state.statusText)
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            }
        }
    }
    
    private func colorForState(_ state: TranscriptionState) -> Color {
        switch state {
        case .notStarted:
            return .semantic(.textSecondary)
        case .inProgress:
            return .semantic(.info)
        case .completed:
            return .semantic(.success)
        case .failed:
            return .semantic(.error)
        }
    }
}

struct TranscriptionActionButton: View {
    let state: TranscriptionState
    let onTap: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        Button(action: {
            if state.isFailed {
                onRetry()
            } else {
                onTap()
            }
        }) {
            HStack(spacing: 6) {
                if state.isFailed {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                        .fontWeight(.medium)
                        .accessibilityLabel("Retry transcription")
                    Text("Retry")
                        .font(.body)
                        .fontWeight(.medium)
                } else if state.isCompleted {
                    Image(systemName: "doc.text")
                        .font(.body)
                        .fontWeight(.medium)
                        .accessibilityLabel("View transcription")
                    Text("View")
                        .font(.body)
                        .fontWeight(.medium)
                } else if state.isInProgress {
                    Text("Processing...")
                        .font(.body)
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "waveform")
                        .font(.body)
                        .fontWeight(.medium)
                        .accessibilityLabel("Start transcription")
                    Text("Transcribe")
                        .font(.body)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(state.isFailed ? .semantic(.warning) : .semantic(.brandPrimary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((state.isFailed ? Color.semantic(.warning) : Color.semantic(.brandPrimary)).opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .disabled(state.isInProgress)
    }
}
