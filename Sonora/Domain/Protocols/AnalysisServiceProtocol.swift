import Foundation
import Combine

protocol AnalysisServiceProtocol: ObservableObject {
    func analyze<T: Codable & Sendable>(mode: AnalysisMode, transcript: String, responseType: T.Type) async throws -> AnalyzeEnvelope<T>
    
    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData>
    func analyzeAnalysis(transcript: String) async throws -> AnalyzeEnvelope<AnalysisData>
    func analyzeThemes(transcript: String) async throws -> AnalyzeEnvelope<ThemesData>
    func analyzeTodos(transcript: String) async throws -> AnalyzeEnvelope<TodosData>
}