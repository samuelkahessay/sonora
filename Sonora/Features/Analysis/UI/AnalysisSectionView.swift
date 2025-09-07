// Moved to Features/Analysis/UI
import SwiftUI

struct AnalysisSectionView: View {
    let transcript: String
    @ObservedObject var viewModel: MemoDetailViewModel
    
    var body: some View {
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
                HStack(spacing: 12) {
                    Image(systemName: AnalysisMode.distill.iconName)
                        .font(.title2)
                        .foregroundColor(.semantic(.textOnColored))
                        .frame(width: 44, height: 44)
                        .background(Color.semantic(.brandPrimary))
                        .clipShape(Circle())
                    let hasCached = viewModel.hasCachedDistill
                    let hasShown = (viewModel.selectedAnalysisMode == .distill && viewModel.analysisResult != nil)
                    Text(
                        viewModel.isAnalyzing ? "Analyzing…" : (
                            hasCached ? (hasShown ? "Distilled" : "View Distill") : AnalysisMode.distill.displayName
                        )
                    )
                    .font(.system(.headline, design: .serif))
                    .fontWeight(.semibold)
                    Spacer()
                    if viewModel.hasCachedDistill && (viewModel.selectedAnalysisMode == .distill && viewModel.analysisResult != nil) {
                        Image(systemName: "water.waves").foregroundColor(.semantic(.brandPrimary))
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .background(Color.semantic(.fillSecondary))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.semantic(.brandPrimary).opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isAnalyzing || (viewModel.hasCachedDistill && viewModel.selectedAnalysisMode == .distill && viewModel.analysisResult != nil))
            .opacity(viewModel.isAnalyzing ? 0.6 : 1.0)
            .accessibilityLabel("Distill")
            .accessibilityHint("Double tap to generate or view AI insights for this memo")

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
            
            
            // Results with AI disclaimer
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
                    } else if let result = viewModel.analysisResult,
                              let envelope = viewModel.analysisEnvelope {
                        AnalysisResultsView(
                            mode: mode,
                            result: result,
                            envelope: envelope
                        )
                    }
                    
//                     AI Disclaimer for analysis results
                    AIDisclaimerView.analysis()
                        .accessibilityLabel("AI disclaimer: Analysis results may contain inaccuracies or subjective interpretations")
                }
                // Do not animate container height when toggling analyzing state
                .animation(nil, value: viewModel.isAnalyzing)
                .accessibilityElement(children: .contain)
            }
        }
        .padding()
        .background(Color.semantic(.bgSecondary))
        .cornerRadius(12)
        .shadow(color: Color.semantic(.separator).opacity(0.2), radius: 2, x: 0, y: 1)
        .frame(maxWidth: .infinity)
    }
}
