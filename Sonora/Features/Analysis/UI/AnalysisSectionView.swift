// Moved to Features/Analysis/UI
import SwiftUI
import Foundation

struct AnalysisSectionView: View {
    let transcript: String
    @ObservedObject var viewModel: MemoDetailViewModel
    
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
                Button(action: {
                    HapticManager.shared.playSelection()
                    let hasCached = viewModel.hasCachedDistill
                    let hasShown = (viewModel.selectedAnalysisMode == .distill && viewModel.analysisResult != nil)
                    if hasCached {
                        if !hasShown { viewModel.restoreCachedDistill() }
                    } else {
                        viewModel.performAnalysis(mode: .distill, transcript: transcript)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: AnalysisMode.distill.iconName)
                            .font(.title3)
                            .foregroundColor(.semantic(.brandPrimary))
                        let hasCached = viewModel.hasCachedDistill
                        let hasShown = (viewModel.selectedAnalysisMode == .distill && viewModel.analysisResult != nil)
                        Text(
                            viewModel.isAnalyzing ? "Analyzing…" : (
                                hasCached ? (hasShown ? "Distilled" : "View Distill") : AnalysisMode.distill.displayName
                            )
                        )
                        .font(.system(.headline, design: .serif))
                        .fontWeight(.semibold)
                        .foregroundColor(.semantic(.textPrimary))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: DistillLayout.buttonHeight, alignment: .center)
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: DistillLayout.buttonCornerRadius, style: .continuous))
                .disabled(viewModel.isAnalyzing || (viewModel.hasCachedDistill && viewModel.selectedAnalysisMode == .distill && viewModel.analysisResult != nil))
                .opacity(viewModel.isAnalyzing ? 0.6 : 1.0)
                .accessibilityLabel("Distill")
                .accessibilityHint("Double tap to generate or view AI insights for this memo")
                .padding(.top, DistillLayout.buttonTopInset)
                .padding(.bottom, DistillLayout.buttonBottomInset)
                .debugBorder(showDebugBorders, color: DistillLayout.debugButtonBorder, cornerRadius: DistillLayout.buttonCornerRadius)
            }

            // Loading State
            if viewModel.isAnalyzing {
                HStack(spacing: 12) {
                    LoadingIndicator(size: .small)
                    Text("Analyzing your memo...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color.semantic(.brandPrimary).opacity(0.05))
                .cornerRadius(8)
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

private enum DistillLayout {
    static let containerCornerRadius: CGFloat = 12
    static let containerVerticalPadding: CGFloat = 12
    static let buttonCornerRadius: CGFloat = 12
    static let buttonHeight: CGFloat = 52
    static let buttonTopInset: CGFloat = 8
    static let buttonBottomInset: CGFloat = 0
    static let debugButtonBorder: Color = .red.opacity(0.5)
    static let debugContainerBorder: Color = .blue.opacity(0.4)
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
