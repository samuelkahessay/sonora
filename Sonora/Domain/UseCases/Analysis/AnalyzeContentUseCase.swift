import Foundation

/// Use case for performing general content analysis on transcript with repository caching
/// Encapsulates the business logic for detailed content analysis with persistence
protocol AnalyzeContentUseCaseProtocol {
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<AnalysisData>
}

final class AnalyzeContentUseCase: AnalyzeContentUseCaseProtocol {
    
    // MARK: - Dependencies
    private let analysisService: AnalysisServiceProtocol
    private let analysisRepository: AnalysisRepository
    
    // MARK: - Initialization
    init(analysisService: AnalysisServiceProtocol, analysisRepository: AnalysisRepository) {
        self.analysisService = analysisService
        self.analysisRepository = analysisRepository
    }
    
    // MARK: - Use Case Execution
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<AnalysisData> {
        // Validate inputs
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscript
        }
        
        guard transcript.count >= 10 else {
            throw AnalysisError.transcriptTooShort
        }
        
        print("📊 AnalyzeContentUseCase: Starting content analysis for memo \(memoId)")
        
        // CACHE FIRST: Check if analysis already exists
        if let cachedResult = await MainActor.run(body: {
            analysisRepository.getAnalysisResult(for: memoId, mode: .analysis, responseType: AnalysisData.self)
        }) {
            print("📊 AnalyzeContentUseCase: Found cached content analysis, returning immediately")
            return cachedResult
        }
        
        print("🌐 AnalyzeContentUseCase: No cached result, calling analysis service")
        
        do {
            // Call service to perform analysis
            let result = try await analysisService.analyzeAnalysis(transcript: transcript)
            
            print("✅ AnalyzeContentUseCase: Content analysis completed successfully")
            print("📊 Generated \(result.data.key_points.count) key points")
            print("💾 AnalyzeContentUseCase: Saving result to repository cache")
            
            // SAVE TO CACHE: Store result for future use
            await MainActor.run {
                analysisRepository.saveAnalysisResult(result, for: memoId, mode: .analysis)
            }
            
            print("✅ AnalyzeContentUseCase: Analysis cached successfully")
            return result
            
        } catch {
            print("❌ AnalyzeContentUseCase: Content analysis failed: \(error)")
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
}