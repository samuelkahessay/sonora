import Foundation

/// Use case for performing todos analysis on transcript with repository caching
/// Encapsulates the business logic for identifying action items and todos with persistence
protocol AnalyzeTodosUseCaseProtocol: Sendable {
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<TodosData>
}

final class AnalyzeTodosUseCase: AnalyzeTodosUseCaseProtocol, @unchecked Sendable {
    
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
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<TodosData> {
        // Validate inputs
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscript
        }
        
        guard transcript.count >= 10 else {
            throw AnalysisError.transcriptTooShort
        }
        
        print("📋 AnalyzeTodosUseCase: Starting todos analysis for memo \(memoId)")
        
        // CACHE FIRST: Check if analysis already exists
        if let cachedResult = await MainActor.run(body: {
            analysisRepository.getAnalysisResult(for: memoId, mode: .todos, responseType: TodosData.self)
        }) {
            print("📋 AnalyzeTodosUseCase: Found cached todos analysis, returning immediately")
            return cachedResult
        }
        
        print("🌐 AnalyzeTodosUseCase: No cached result, calling analysis service")
        
        do {
            // Call service to perform analysis
            let result = try await analysisService.analyzeTodos(transcript: transcript)

            // Guardrails: validate structure before persisting
            guard AnalysisGuardrails.validate(todos: result.data) else {
                print("❌ AnalyzeTodosUseCase: Validation failed — not persisting result")
                throw AnalysisError.invalidResponse
            }
            
            print("✅ AnalyzeTodosUseCase: Todos analysis completed successfully")
            print("📋 Found \(result.data.todos.count) action items")
            print("💾 AnalyzeTodosUseCase: Saving result to repository cache")
            
            // SAVE TO CACHE: Store result for future use
            await MainActor.run {
                analysisRepository.saveAnalysisResult(result, for: memoId, mode: .todos)
            }
            
            print("✅ AnalyzeTodosUseCase: Analysis cached successfully")
            
            // Publish analysisCompleted event on main actor
            print("📡 AnalyzeTodosUseCase: Publishing analysisCompleted event for memo \(memoId)")
            let resultSummary = "\(result.data.todos.count) todos identified"
            await MainActor.run { [eventBus] in
                eventBus.publish(.analysisCompleted(memoId: memoId, type: .todos, result: resultSummary))
            }
            
            return result
            
        } catch {
            print("❌ AnalyzeTodosUseCase: Todos analysis failed: \(error)")
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
}
