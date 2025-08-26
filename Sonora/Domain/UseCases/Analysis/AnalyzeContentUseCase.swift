import Foundation

/// Use case for performing general content analysis on transcript
/// Encapsulates the business logic for detailed content analysis
protocol AnalyzeContentUseCaseProtocol {
    func execute(transcript: String) async throws -> AnalyzeEnvelope<AnalysisData>
}

final class AnalyzeContentUseCase: AnalyzeContentUseCaseProtocol {
    
    // MARK: - Dependencies
    private let analysisService: AnalysisServiceProtocol
    
    // MARK: - Initialization
    init(analysisService: AnalysisServiceProtocol) {
        self.analysisService = analysisService
    }
    
    // MARK: - Use Case Execution
    func execute(transcript: String) async throws -> AnalyzeEnvelope<AnalysisData> {
        // Validate transcript
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscript
        }
        
        // Check transcript length
        guard transcript.count >= 10 else {
            throw AnalysisError.transcriptTooShort
        }
        
        print("📊 AnalyzeContentUseCase: Starting content analysis")
        
        do {
            let result = try await analysisService.analyzeAnalysis(transcript: transcript)
            
            print("✅ AnalyzeContentUseCase: Content analysis completed successfully")
            print("📊 Generated \(result.data.key_points.count) key points")
            
            return result
            
        } catch {
            print("❌ AnalyzeContentUseCase: Content analysis failed: \(error)")
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
}