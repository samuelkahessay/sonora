import SwiftUI

struct AnalysisSectionView: View {
    let transcript: String
    @Binding var isAnalyzing: Bool
    @Binding var analysisError: String?
    @Binding var selectedAnalysisMode: AnalysisMode?
    @Binding var analysisResult: Any?
    @Binding var analysisEnvelope: Any?
    let analysisService: AnalysisService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Analysis Buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(AnalysisMode.allCases, id: \.self) { mode in
                    Button(action: {
                        performAnalysis(mode: mode)
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: mode.iconName)
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .clipShape(Circle())
                            
                            Text(mode.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isAnalyzing)
                    .opacity(isAnalyzing ? 0.6 : 1.0)
                }
            }
            
            // Loading State
            if isAnalyzing {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing with AI...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            
            // Error State
            if let error = analysisError {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Analysis Failed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.05))
                .cornerRadius(8)
            }
            
            // Results
            if let mode = selectedAnalysisMode,
               let result = analysisResult,
               let envelope = analysisEnvelope {
                AnalysisResultsView(
                    mode: mode,
                    result: result,
                    envelope: envelope
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    private func performAnalysis(mode: AnalysisMode) {
        isAnalyzing = true
        analysisError = nil
        selectedAnalysisMode = mode
        analysisResult = nil
        analysisEnvelope = nil
        
        Task {
            do {
                switch mode {
                case .tldr:
                    let envelope = try await analysisService.analyzeTLDR(transcript: transcript)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                    }
                    
                case .analysis:
                    let envelope = try await analysisService.analyzeAnalysis(transcript: transcript)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                    }
                    
                case .themes:
                    let envelope = try await analysisService.analyzeThemes(transcript: transcript)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                    }
                    
                case .todos:
                    let envelope = try await analysisService.analyzeTodos(transcript: transcript)
                    await MainActor.run {
                        analysisResult = envelope.data
                        analysisEnvelope = envelope
                        isAnalyzing = false
                    }
                }
            } catch {
                await MainActor.run {
                    analysisError = error.localizedDescription
                    isAnalyzing = false
                }
                print("❌ Analysis failed: \(error)")
            }
        }
    }
}