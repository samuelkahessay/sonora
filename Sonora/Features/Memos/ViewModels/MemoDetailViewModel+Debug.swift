import Foundation

// MARK: - Debug Helpers

extension MemoDetailViewModel {

    /// Get debug information about the current state
    var debugInfo: String {
        """
        MemoDetailViewModel State:
        - currentMemo: \(debugCurrentMemoFilename)
        - transcriptionState: \(state.transcription.state.statusText)
        - isPlaying: \(state.audio.isPlaying)
        - isAnalyzing: \(state.analysis.isAnalyzing)
        - selectedAnalysisMode: \(state.analysis.selectedMode?.displayName ?? "none")
        - analysisError: \(state.analysis.error ?? "none")
        - error: \(state.ui.error?.localizedDescription ?? "none")
        - isLoading: \(state.ui.isLoading)
        """
    }

    // MARK: - ErrorHandling Protocol

    func retryLastOperation() {
        clearError()
        guard memoId != nil else { return }

        // Determine what operation to retry based on current state
        if state.transcription.state.isFailed {
            retryTranscription()
        } else if !state.transcription.state.isCompleted {
            startTranscription()
        }
    }
}

