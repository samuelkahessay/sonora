import Foundation

/// Use case for performing TLDR analysis on transcript with repository caching
/// Encapsulates the business logic for generating TLDR summaries with persistence
protocol AnalyzeTLDRUseCaseProtocol {
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<TLDRData>
}

final class AnalyzeTLDRUseCase: AnalyzeTLDRUseCaseProtocol {
    
    // MARK: - Dependencies
    private let analysisService: AnalysisServiceProtocol
    private let analysisRepository: AnalysisRepository
    
    // MARK: - Initialization
    init(analysisService: AnalysisServiceProtocol, analysisRepository: AnalysisRepository) {
        self.analysisService = analysisService
        self.analysisRepository = analysisRepository
    }
    
    // MARK: - Use Case Execution
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<TLDRData> {
        // Validate inputs
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscript
        }
        
        guard transcript.count >= 10 else {
            throw AnalysisError.transcriptTooShort
        }
        
        print("🔍 AnalyzeTLDRUseCase: Starting TLDR analysis for memo \(memoId)")
        
        // CACHE FIRST: Check if analysis already exists
        if let cachedResult = await MainActor.run(body: {
            analysisRepository.getAnalysisResult(for: memoId, mode: .tldr, responseType: TLDRData.self)
        }) {
            print("🎯 AnalyzeTLDRUseCase: Found cached TLDR analysis, returning immediately")
            return cachedResult
        }
        
        print("🌐 AnalyzeTLDRUseCase: No cached result, calling analysis service")
        
        do {
            // Call service to perform analysis
            let result = try await analysisService.analyzeTLDR(transcript: transcript)
            
            print("✅ AnalyzeTLDRUseCase: TLDR analysis completed successfully")
            print("💾 AnalyzeTLDRUseCase: Saving result to repository cache")
            
            // SAVE TO CACHE: Store result for future use
            await MainActor.run {
                analysisRepository.saveAnalysisResult(result, for: memoId, mode: .tldr)
            }
            
            print("✅ AnalyzeTLDRUseCase: Analysis cached successfully")
            return result
            
        } catch {
            print("❌ AnalyzeTLDRUseCase: TLDR analysis failed: \(error)")
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
}

