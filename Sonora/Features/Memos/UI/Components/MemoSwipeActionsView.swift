import SwiftUI

struct MemoSwipeActionsView: View {
    let memo: Memo
    @ObservedObject var viewModel: MemoListViewModel
    @State private var transcriptionState: TranscriptionState = .notStarted

    var body: some View {
        Group {
            deleteButton
            contextualTranscriptionActions
        }
        .task(id: memo.id) {
            transcriptionState = await viewModel.getTranscriptionState(for: memo)
        }
    }

    @ViewBuilder
    private var contextualTranscriptionActions: some View {
        let state = transcriptionState
        if state.isNotStarted {
            Button {
                HapticManager.shared.playSelection()
                viewModel.startTranscription(for: memo)
            } label: {
                Label(MemoListConstants.SwipeActions.transcribeTitle,
                      systemImage: MemoListConstants.SwipeActions.transcribeIcon)
            }
            .tint(.semantic(.brandPrimary))
            .accessibilityLabel("Transcribe \(memo.displayName)")
            .accessibilityHint(MemoListConstants.AccessibilityLabels.transcribeHint)
        } else if state.isFailed {
            // Avoid showing retry for 'no speech' failures
            if case .failed(let error) = state {
                let lower = error.lowercased()
                if !(lower.contains("no speech") || error == TranscriptionError.noSpeechDetected.errorDescription) {
                    Button {
                        HapticManager.shared.playSelection()
                        viewModel.retryTranscription(for: memo)
                    } label: {
                        Label(MemoListConstants.SwipeActions.retryTitle,
                              systemImage: MemoListConstants.SwipeActions.retryIcon)
                    }
                    .tint(.semantic(.warning))
                    .accessibilityLabel("Retry transcription for \(memo.displayName)")
                    .accessibilityHint(MemoListConstants.AccessibilityLabels.retryHint)
                }
            }
        }
    }

    @ViewBuilder
    private var deleteButton: some View {
        Button(role: .destructive) {
            HapticManager.shared.playDeletionFeedback()
            if let idx = viewModel.memos.firstIndex(where: { $0.id == memo.id }) {
                viewModel.deleteMemo(at: idx)
            }
        } label: {
            Label(MemoListConstants.SwipeActions.deleteTitle,
                  systemImage: MemoListConstants.SwipeActions.deleteIcon)
        }
        .accessibilityLabel("Delete \(memo.displayName)")
        .accessibilityHint(MemoListConstants.AccessibilityLabels.deleteHint)
    }
}

#Preview {
    let vm = DIContainer.shared.viewModelFactory().createMemoListViewModel()
    let memo = Memo(
        filename: "Test.m4a",
        fileURL: URL(fileURLWithPath: "/dev/null"),
        creationDate: Date(),
        transcriptionStatus: .notStarted,
        analysisResults: []
    )
    return MemoSwipeActionsView(memo: memo, viewModel: vm)
}
