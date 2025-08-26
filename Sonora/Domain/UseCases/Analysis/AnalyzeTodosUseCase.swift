import Foundation

/// Use case for performing todos analysis on transcript
/// Encapsulates the business logic for identifying action items and todos
protocol AnalyzeTodosUseCaseProtocol {
    func execute(transcript: String) async throws -> AnalyzeEnvelope<TodosData>
}

final class AnalyzeTodosUseCase: AnalyzeTodosUseCaseProtocol {
    
    // MARK: - Dependencies
    private let analysisService: AnalysisServiceProtocol
    
    // MARK: - Initialization
    init(analysisService: AnalysisServiceProtocol) {
        self.analysisService = analysisService
    }
    
    // MARK: - Use Case Execution
    func execute(transcript: String) async throws -> AnalyzeEnvelope<TodosData> {
        // Validate transcript
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscript
        }
        
        // Check transcript length
        guard transcript.count >= 10 else {
            throw AnalysisError.transcriptTooShort
        }
        
        print("✅ AnalyzeTodosUseCase: Starting todos analysis")
        
        do {
            let result = try await analysisService.analyzeTodos(transcript: transcript)
            
            print("✅ AnalyzeTodosUseCase: Todos analysis completed successfully")
            print("📋 Found \(result.data.todos.count) action items")
            
            return result
            
        } catch {
            print("❌ AnalyzeTodosUseCase: Todos analysis failed: \(error)")
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
}