import Combine
import Foundation

protocol AnalysisServiceProtocol: ObservableObject, Sendable {
    func analyze<T: Codable & Sendable>(mode: AnalysisMode, transcript: String, responseType: T.Type) async throws -> AnalyzeEnvelope<T>

    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData>
    func analyzeAnalysis(transcript: String) async throws -> AnalyzeEnvelope<AnalysisData>
    func analyzeThemes(transcript: String) async throws -> AnalyzeEnvelope<ThemesData>
    func analyzeTodos(transcript: String) async throws -> AnalyzeEnvelope<TodosData>

    // Distill component methods for parallel processing
    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData>
    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData>
    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData>
    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData>
}
