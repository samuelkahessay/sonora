import Foundation
import Combine

protocol AnalysisRepository: ObservableObject {
    func saveAnalysisResult<T: Codable>(_ result: AnalyzeEnvelope<T>, for memoId: UUID, mode: AnalysisMode)
    func getAnalysisResult<T: Codable>(for memoId: UUID, mode: AnalysisMode, responseType: T.Type) -> AnalyzeEnvelope<T>?
    func hasAnalysisResult(for memoId: UUID, mode: AnalysisMode) -> Bool
    func deleteAnalysisResults(for memoId: UUID)
    func deleteAnalysisResult(for memoId: UUID, mode: AnalysisMode)
    func getAllAnalysisResults(for memoId: UUID) -> [AnalysisMode: Any]
    func clearCache()
    func getCacheSize() -> Int
    func getAnalysisHistory(for memoId: UUID) -> [(mode: AnalysisMode, timestamp: Date)]
}