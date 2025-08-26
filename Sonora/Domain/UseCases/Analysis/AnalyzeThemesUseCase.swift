import Foundation

/// Use case for performing themes analysis on transcript
/// Encapsulates the business logic for identifying themes and sentiment
protocol AnalyzeThemesUseCaseProtocol {
    func execute(transcript: String) async throws -> AnalyzeEnvelope<ThemesData>
}

final class AnalyzeThemesUseCase: AnalyzeThemesUseCaseProtocol {
    
    // MARK: - Dependencies
    private let analysisService: AnalysisServiceProtocol
    
    // MARK: - Initialization
    init(analysisService: AnalysisServiceProtocol) {
        self.analysisService = analysisService
    }
    
    // MARK: - Use Case Execution
    func execute(transcript: String) async throws -> AnalyzeEnvelope<ThemesData> {
        // Validate transcript
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscript
        }
        
        // Check transcript length
        guard transcript.count >= 10 else {
            throw AnalysisError.transcriptTooShort
        }
        
        print("🎯 AnalyzeThemesUseCase: Starting themes analysis")
        
        do {
            let result = try await analysisService.analyzeThemes(transcript: transcript)
            
            print("✅ AnalyzeThemesUseCase: Themes analysis completed successfully")
            print("🎯 Found \(result.data.themes.count) themes with sentiment: \(result.data.sentiment)")
            
            return result
            
        } catch {
            print("❌ AnalyzeThemesUseCase: Themes analysis failed: \(error)")
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
}