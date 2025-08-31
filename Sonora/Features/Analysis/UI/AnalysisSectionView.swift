// Moved to Features/Analysis/UI
import SwiftUI

struct AnalysisSectionView: View {
    let transcript: String
    @ObservedObject var viewModel: MemoDetailViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("AI Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                AIBadge()
                    .accessibilityHidden(true)
            }
            
            // Analysis Buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(AnalysisMode.allCases, id: \.self) { mode in
                    Button(action: {
                        HapticManager.shared.playSelection()
                        viewModel.performAnalysis(mode: mode, transcript: transcript)
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: mode.iconName)
                                .font(.title2)
                                .foregroundColor(.semantic(.textInverted))
                                .frame(minWidth: 44, minHeight: 44)
                                .background(Color.semantic(.brandPrimary))
                                .clipShape(Circle())
                            
                            Text(mode.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.semantic(.fillSecondary))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.semantic(.brandPrimary).opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.isAnalyzing)
                    .opacity(viewModel.isAnalyzing ? 0.6 : 1.0)
                    .accessibilityLabel("\(mode.displayName) analysis")
                    .accessibilityHint("Double tap to analyze transcript for \(mode.displayName.lowercased())")
                    // Disabled state is conveyed by .disabled(); keep traits minimal
                    .accessibilityAddTraits([])
                }
            }
            
            // Loading State
            if viewModel.isAnalyzing {
                HStack(spacing: 12) {
                    LoadingIndicator(size: .small)
                    Text("Analyzing with AI...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color.semantic(.brandPrimary).opacity(0.05))
                .cornerRadius(8)
            }
            
            // Error State
            if let error = viewModel.analysisError {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.semantic(.error))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Analysis Failed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.semantic(.error))
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                    Spacer()
                }
                .padding()
                .background(Color.semantic(.error).opacity(0.05))
                .cornerRadius(8)
            }
            
            // Results with AI disclaimer
            if let mode = viewModel.selectedAnalysisMode,
               let result = viewModel.analysisResult,
               let envelope = viewModel.analysisEnvelope {
                VStack(alignment: .leading, spacing: 12) {
                    AnalysisResultsView(
                        mode: mode,
                        result: result,
                        envelope: envelope
                    )
                    
                    // AI Disclaimer for analysis results
                    AIDisclaimerView.analysis()
                        .accessibilityLabel("AI disclaimer: Analysis results may contain inaccuracies or subjective interpretations")
                }
                .accessibilityElement(children: .contain)
            }
        }
        .padding()
        .background(Color.semantic(.bgSecondary))
        .cornerRadius(12)
        .shadow(color: Color.semantic(.separator).opacity(0.2), radius: 2, x: 0, y: 1)
    }
}
