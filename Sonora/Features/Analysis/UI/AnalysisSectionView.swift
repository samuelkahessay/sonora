import Foundation
import SwiftUI

struct AnalysisSectionView: View {
    let transcript: String
    @ObservedObject var viewModel: MemoDetailViewModel
    @State private var loaderMessageIndex = -1

    var body: some View {
        let state = viewModel.autoDistillState
        let isDistillCompleted = state.isSuccess || viewModel.analysisPayload != nil
        let showDebugBorders = LayoutDebug.distillButton
        VStack(alignment: .leading, spacing: 16) {
            if let err = viewModel.analysisError {
                NotificationBanner(
                    type: .error,
                    message: err,
                    onPrimaryAction: {
                        viewModel.retryDistillation()
                    },
                    onDismiss: {
                        viewModel.analysisError = nil
                    }
                )
            }

            if case .failed(let reason, let message) = state {
                DistillFailureView(reason: reason, message: message) {
                    viewModel.retryDistillation()
                }
            }

            if isLoading(state: state) {
                let loaderMessage = currentLoaderMessage
                HStack(spacing: 12) {
                    LoadingIndicator(size: .small)
                    Text(loaderMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .id(loaderMessageIndex)
                    Spacer()
                }
                .padding()
                .background(Color.semantic(.fillSecondary))
                .cornerRadius(8)
                .animation(SonoraDesignSystem.Animation.loaderMessage, value: loaderMessageIndex)
            }

            VStack(alignment: .leading, spacing: 12) {
                if case .streaming(let progress) = state, let progress = progress {
                    DistillResultView(partialData: progress.completedResults, progress: progress, memoId: viewModel.memoId)
                        .transition(.opacity)
                        .animation(SonoraDesignSystem.Animation.progressUpdate, value: progress.completedComponents)
                    if progress.completedComponents > 0 {
                        AIDisclaimerView.analysis()
                            .transition(.opacity)
                            .animation(SonoraDesignSystem.Animation.progressUpdate, value: progress.completedComponents)
                    }
                } else if case .success = state, let payload = viewModel.analysisPayload {
                    AnalysisResultsView(
                        payload: payload,
                        memoId: viewModel.memoId
                    )
                    AIDisclaimerView.analysis()
                        .accessibilityLabel("AI disclaimer. Review for accuracy. Learn more.")
                } else if case .success = state {
                    loaderPlaceholder
                }
            }
            .animation(nil, value: state)
            .accessibilityElement(children: .contain)
        }
        .modifier(AnalysisContainerStyle(isCompleted: isDistillCompleted, showDebugBorder: showDebugBorders))
        .frame(maxWidth: .infinity)
        .onChange(of: state) { _, newValue in
            guard case .inProgress = newValue, !DistillCopy.loaderMessages.isEmpty else { return }
            loaderMessageIndex = (loaderMessageIndex + 1) % DistillCopy.loaderMessages.count
        }
    }

    private var currentLoaderMessage: String {
        DistillCopy.loaderMessages[safe: loaderMessageIndex] ?? DistillCopy.loaderMessages.first ?? "Analyzing your memo..."
    }

    private func isLoading(state: DistillationState) -> Bool {
        switch state {
        case .inProgress:
            return true
        case .streaming:
            return false
        case .success, .failed, .idle:
            return false
        }
    }

    private var loaderPlaceholder: some View {
        HStack(spacing: 12) {
            LoadingIndicator(size: .small)
            Text("Loading analysis...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .background(Color.semantic(.fillSecondary))
        .cornerRadius(8)
    }
}

// Flatter container when completed; card-like container otherwise
private struct AnalysisContainerStyle: ViewModifier {
    let isCompleted: Bool
    let showDebugBorder: Bool
    func body(content: Content) -> some View {
        if isCompleted {
            content
                .padding(.vertical, DistillLayout.containerVerticalPadding)
                .debugBorder(showDebugBorder, color: DistillLayout.debugContainerBorder, cornerRadius: DistillLayout.containerCornerRadius)
        } else {
            // Remove outer background container to preserve symmetry
            // with other cards on the detail screen. The Distill CTA
            // itself remains a single card with its own background.
            content
                .padding(.vertical, DistillLayout.containerVerticalPadding)
                .debugBorder(showDebugBorder, color: DistillLayout.debugContainerBorder, cornerRadius: DistillLayout.containerCornerRadius)
        }
    }
}

private struct DistillFailureView: View {
    let reason: DistillationFailureReason
    let message: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Analysis failed: \(reason.displayName)")
                    .font(.headline)
                    .foregroundColor(.semantic(.textPrimary))
            }
            if let message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button("Retry Analysis", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.semantic(.fillSecondary))
        .cornerRadius(10)
    }
}

private enum DistillLayout {
    static let containerCornerRadius: CGFloat = 12
    static let containerVerticalPadding: CGFloat = 12
    static let debugButtonBorder: Color = .red.opacity(0.5)
    static let debugContainerBorder: Color = .blue.opacity(0.4)
}

private enum DistillCopy {
    static let loaderMessages: [String] = [
        "Turning chaos into clarity",
        "Distilling your voice",
        "Listening for what matters",
        "Letting meaning rise to the surface",
        "Tracing the path through your thoughts",
        "Making room for the insight ahead",
        "Organizing your thoughts",
        "Surfacing what matters",
        "Extracting the signal",
        "Bringing structure to speech",
        "Mapping the meaning",
        "Decoding your direction",
        "Reading between the lines"
    ]
}

#if DEBUG
private enum LayoutDebug {
    static let distillButton = ProcessInfo.processInfo.environment["DISTILL_DEBUG_BORDER"] == "1"
}
#else
private enum LayoutDebug {
    static let distillButton = false
}
#endif

private struct DebugBorderModifier: ViewModifier {
    let show: Bool
    let color: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if show {
            content.overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        } else {
            content
        }
    }
}

private extension View {
    func debugBorder(_ show: Bool, color: Color, cornerRadius: CGFloat) -> some View {
        modifier(DebugBorderModifier(show: show, color: color, cornerRadius: cornerRadius))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
