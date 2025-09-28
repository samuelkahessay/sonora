// Moved to Features/Analysis/UI
import SwiftUI
import Foundation

struct AnalysisSectionView: View {
    let transcript: String
    @ObservedObject var viewModel: MemoDetailViewModel
    @State private var loaderMessageIndex = -1
    
    var body: some View {
        let isDistillCompleted = (viewModel.selectedAnalysisMode == .distill && viewModel.analysisResult != nil)
        let showDebugBorders = LayoutDebug.distillButton
        VStack(alignment: .leading, spacing: 16) {
            // Analysis error banner at top with retry
            if let err = viewModel.analysisError {
                NotificationBanner(
                    type: .error,
                    message: err,
                    onPrimaryAction: {
                        viewModel.performAnalysis(mode: .distill, transcript: transcript)
                    },
                    onDismiss: {
                        viewModel.analysisError = nil
                    }
                )
            }
            if isDistillCompleted {
                // Flatter header once analysis is complete (centered)
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundColor(.semantic(.brandPrimary))
                    Text("Distilled")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.semantic(.textPrimary))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
            } else {
                let hasCached = viewModel.hasCachedDistill
                let hasShown = (viewModel.selectedAnalysisMode == .distill && viewModel.analysisResult != nil)
                let isAnalyzing = viewModel.isAnalyzing

                DistillCTAButton(
                    isAnalyzing: isAnalyzing,
                    hasCachedResult: hasCached,
                    hasShownCachedResult: hasShown,
                    action: {
                        HapticManager.shared.playSelection()
                        if hasCached {
                            if !hasShown {
                                viewModel.restoreCachedDistill()
                            }
                        } else {
                            viewModel.performAnalysis(mode: .distill, transcript: transcript)
                        }
                    }
                )
                .buttonStyle(PressableCardButtonStyle())
                .contentShape(RoundedRectangle(cornerRadius: DistillLayout.buttonCornerRadius, style: .continuous))
                .disabled(isAnalyzing || (hasCached && hasShown))
                .accessibilityLabel(hasCached ? "View Distill" : "Distill")
                .accessibilityHint(hasCached ? "Double tap to open the saved AI insight" : "Double tap to generate AI insights for this memo")
                .debugBorder(showDebugBorders, color: DistillLayout.debugButtonBorder, cornerRadius: DistillLayout.buttonCornerRadius)
            }

            // Loading State
            if viewModel.isAnalyzing {
                let loaderMessage = DistillCopy.loaderMessages[safe: loaderMessageIndex] ?? DistillCopy.loaderMessages.first ?? "Distilling your voice"
                HStack(spacing: 12) {
                    LoadingIndicator(size: .small)
                    Text(loaderMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .id(loaderMessageIndex)
                    Spacer()
                }
                .padding()
                .background(Color.semantic(.brandPrimary).opacity(0.05))
                .cornerRadius(8)
                .animation(.easeInOut(duration: 0.35), value: loaderMessageIndex)
            }
            
            // Results with AI disclaimer (only when there are results)
            if let mode = viewModel.selectedAnalysisMode {
                VStack(alignment: .leading, spacing: 12) {
                    // Show progressive results for parallel distill or final results
                    if mode == .distill && viewModel.isParallelDistillEnabled,
                       let partialData = viewModel.partialDistillData,
                       let progress = viewModel.distillProgress {
                        DistillResultView(partialData: partialData, progress: progress)
                            // Avoid scale transitions that can cause visual overlap with siblings
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: progress.completedComponents)

                        // Show disclaimer when any partial results are present
                        if progress.completedComponents > 0 {
                            AIDisclaimerView.analysis()
                                .transition(.opacity)
                                .animation(.easeIn(duration: 0.3), value: progress.completedComponents)
                        }
                    } else if let result = viewModel.analysisResult,
                              let envelope = viewModel.analysisEnvelope {
                        AnalysisResultsView(
                            mode: mode,
                            result: result,
                            envelope: envelope
                        )

                        // Show disclaimer only with actual results
                        AIDisclaimerView.analysis()
                            .accessibilityLabel("AI disclaimer. Review for accuracy. Learn more.")
                    }
                }
                // Do not animate container height when toggling analyzing state
                .animation(nil, value: viewModel.isAnalyzing)
                .accessibilityElement(children: .contain)
            }
        }
        .modifier(AnalysisContainerStyle(isCompleted: isDistillCompleted, showDebugBorder: showDebugBorders))
        .frame(maxWidth: .infinity)
        .onChange(of: viewModel.isAnalyzing) { _, isAnalyzing in
            guard isAnalyzing, !DistillCopy.loaderMessages.isEmpty else { return }
            loaderMessageIndex = (loaderMessageIndex + 1) % DistillCopy.loaderMessages.count
        }
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
            content
                .padding(.vertical, DistillLayout.containerVerticalPadding)
                .padding(.horizontal, 16)
                .background(Color.semantic(.bgSecondary))
                .cornerRadius(DistillLayout.containerCornerRadius)
                .debugBorder(showDebugBorder, color: DistillLayout.debugContainerBorder, cornerRadius: DistillLayout.containerCornerRadius)
        }
    }
}

private struct DistillCTAButton: View {
    let isAnalyzing: Bool
    let hasCachedResult: Bool
    let hasShownCachedResult: Bool
    let action: () -> Void

    private var displayText: String {
        hasCachedResult ? "View Distill" : AnalysisMode.distill.displayName
    }

    private var trailingIcon: some View {
        Group {
            if hasCachedResult && !isAnalyzing && !hasShownCachedResult {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: AnalysisMode.distill.iconName)
                    .font(.title3)
                    .foregroundColor(.semantic(.brandPrimary))

                if isAnalyzing {
                    LoadingIndicator(size: .small)
                        .frame(width: 16, height: 16)
                }

                Text(displayText)
                    .font(.system(.headline, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))

                Spacer(minLength: 0)

                trailingIcon
            }
            .padding(.vertical, DistillLayout.buttonVerticalPadding)
            .padding(.horizontal, DistillLayout.buttonHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.semantic(.fillSecondary))
            .overlay(
                RoundedRectangle(cornerRadius: DistillLayout.buttonCornerRadius, style: .continuous)
                    .stroke(Color.semantic(.brandPrimary).opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(DistillLayout.buttonCornerRadius)
        }
    }
}

private struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

private enum DistillLayout {
    static let containerCornerRadius: CGFloat = 12
    static let containerVerticalPadding: CGFloat = 12
    static let buttonCornerRadius: CGFloat = 12
    static let buttonVerticalPadding: CGFloat = 14
    static let buttonHorizontalPadding: CGFloat = 16
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
