import Foundation

/// Use case for performing themes analysis on transcript with repository caching
/// Encapsulates the business logic for identifying themes and sentiment with persistence
protocol AnalyzeThemesUseCaseProtocol {
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<ThemesData>
}

final class AnalyzeThemesUseCase: AnalyzeThemesUseCaseProtocol {
    
    // MARK: - Dependencies
    private let analysisService: any AnalysisServiceProtocol
    private let analysisRepository: any AnalysisRepository
    private let logger: any LoggerProtocol
    private let eventBus: any EventBusProtocol
    
    // MARK: - Initialization
    init(
        analysisService: any AnalysisServiceProtocol, 
        analysisRepository: any AnalysisRepository,
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol
    ) {
        self.analysisService = analysisService
        self.analysisRepository = analysisRepository
        self.logger = logger
        self.eventBus = eventBus
    }
    
    // MARK: - Use Case Execution
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<ThemesData> {
        // Validate inputs
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscript
        }
        
        guard transcript.count >= 10 else {
            throw AnalysisError.transcriptTooShort
        }
        
        print("🎯 AnalyzeThemesUseCase: Starting themes analysis for memo \(memoId)")
        
        // CACHE FIRST: Check if analysis already exists
        if let cachedResult = await MainActor.run(body: {
            analysisRepository.getAnalysisResult(for: memoId, mode: .themes, responseType: ThemesData.self)
        }) {
            print("🎯 AnalyzeThemesUseCase: Found cached themes analysis, returning immediately")
            return cachedResult
        }
        
        print("🌐 AnalyzeThemesUseCase: No cached result, calling analysis service")
        
        do {
            // Call service to perform analysis
            let result = try await analysisService.analyzeThemes(transcript: transcript)

            // Guardrails: validate structure before persisting
            guard AnalysisGuardrails.validate(themes: result.data) else {
                print("❌ AnalyzeThemesUseCase: Validation failed — not persisting result")
                throw AnalysisError.invalidResponse
            }
            
            print("✅ AnalyzeThemesUseCase: Themes analysis completed successfully")
            print("🎯 Found \(result.data.themes.count) themes with sentiment: \(result.data.sentiment)")
            print("💾 AnalyzeThemesUseCase: Saving result to repository cache")
            
            // SAVE TO CACHE: Store result for future use
            await MainActor.run {
                analysisRepository.saveAnalysisResult(result, for: memoId, mode: .themes)
            }
            
            print("✅ AnalyzeThemesUseCase: Analysis cached successfully")
            
            // Publish analysisCompleted event on main actor
            print("📡 AnalyzeThemesUseCase: Publishing analysisCompleted event for memo \(memoId)")
            let resultSummary = "\(result.data.themes.count) themes, sentiment: \(result.data.sentiment)"
            await MainActor.run { [eventBus] in
                eventBus.publish(.analysisCompleted(memoId: memoId, type: .themes, result: resultSummary))
            }
            
            return result
            
        } catch {
            print("❌ AnalyzeThemesUseCase: Themes analysis failed: \(error)")
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
}
