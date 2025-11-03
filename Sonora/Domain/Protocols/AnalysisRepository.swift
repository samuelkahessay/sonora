import Foundation

/// Sendable summary of available analysis results for a memo
public struct AnalysisResultsSummary: Sendable {
    public let availableModes: Set<AnalysisMode>
    public let count: Int

    public init(availableModes: Set<AnalysisMode>) {
        self.availableModes = availableModes
        self.count = availableModes.count
    }
}

/// Analysis repository protocol for managing analysis results cache and persistence.
/// Protocol is actor-agnostic (Sendable) - implementations choose their isolation.
protocol AnalysisRepository: Sendable {
    func saveAnalysisResult<T: Codable & Sendable>(_ result: AnalyzeEnvelope<T>, for memoId: UUID, mode: AnalysisMode) async
    func getAnalysisResult<T: Codable & Sendable>(for memoId: UUID, mode: AnalysisMode, responseType: T.Type) async -> AnalyzeEnvelope<T>?
    func hasAnalysisResult(for memoId: UUID, mode: AnalysisMode) async -> Bool
    func deleteAnalysisResults(for memoId: UUID) async
    func deleteAnalysisResult(for memoId: UUID, mode: AnalysisMode) async
    func getAllAnalysisResults(for memoId: UUID) async -> AnalysisResultsSummary
    func clearCache() async
    func getCacheSize() async -> Int
    func getAnalysisHistory(for memoId: UUID) async -> [(mode: AnalysisMode, timestamp: Date)]
}
