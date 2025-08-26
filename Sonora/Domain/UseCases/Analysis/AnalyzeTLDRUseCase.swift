import Foundation

/// Use case for performing TLDR analysis on transcript
/// Encapsulates the business logic for generating TLDR summaries
protocol AnalyzeTLDRUseCaseProtocol {
    func execute(transcript: String) async throws -> AnalyzeEnvelope<TLDRData>
}

final class AnalyzeTLDRUseCase: AnalyzeTLDRUseCaseProtocol {
    
    // MARK: - Dependencies
    private let analysisService: AnalysisServiceProtocol
    
    // MARK: - Initialization
    init(analysisService: AnalysisServiceProtocol) {
        self.analysisService = analysisService
    }
    
    // MARK: - Use Case Execution
    func execute(transcript: String) async throws -> AnalyzeEnvelope<TLDRData> {
        // Validate transcript
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscript
        }
        
        // Check transcript length
        guard transcript.count >= 10 else {
            throw AnalysisError.transcriptTooShort
        }
        
        print("🔍 AnalyzeTLDRUseCase: Starting TLDR analysis")
        
        do {
            let result = try await analysisService.analyzeTLDR(transcript: transcript)
            
            print("✅ AnalyzeTLDRUseCase: TLDR analysis completed successfully")
            return result
            
        } catch {
            print("❌ AnalyzeTLDRUseCase: TLDR analysis failed: \(error)")
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
}

