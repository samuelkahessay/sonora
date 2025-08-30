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
                ProgressView()
                    .scaleEffect(compact ? 0.7 : 1.0)
                    .frame(width: compact ? 12 : 16, height: compact ? 12 : 16)
            } else {
                Image(systemName: state.iconName)
                    .foregroundColor(colorForState(state))
                    .font(compact ? .caption2 : .caption)
                    .fontWeight(.medium)
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
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Retry")
                        .font(.caption)
                        .fontWeight(.medium)
                } else if state.isCompleted {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("View")
                        .font(.caption)
                        .fontWeight(.medium)
                } else if state.isInProgress {
                    Text("Processing...")
                        .font(.caption)
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Transcribe")
                        .font(.caption)
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
        .buttonStyle(PlainButtonStyle())
        .disabled(state.isInProgress)
    }
}
