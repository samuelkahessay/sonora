import Foundation

protocol AnalysisServiceProtocol: Sendable {
    // Base analyze method - implementations should provide default nil for historicalContext
    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]?,
        isPro: Bool
    ) async throws -> AnalyzeEnvelope<T>

    // Convenience method for distill with historical context and pro flag
    func analyzeDistill(
        transcript: String,
        historicalContext: [HistoricalMemoContext]?,
        isPro: Bool
    ) async throws -> AnalyzeEnvelope<DistillData>

    // Convenience method for distill without historical context (backward compatibility)
    func analyzeDistill(transcript: String, isPro: Bool) async throws -> AnalyzeEnvelope<DistillData>

    // Free tier lite distill
    func analyzeLiteDistill(transcript: String) async throws -> AnalyzeEnvelope<LiteDistillData>

    // MARK: - SSE Streaming Methods

    /// Analyze with Server-Sent Events (SSE) streaming for progressive updates
    func analyzeWithStreaming<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]?,
        isPro: Bool,
        onProgress: @escaping @Sendable (AnalysisStreamingUpdate) -> Void
    ) async throws -> AnalyzeEnvelope<T>

    /// Convenience method for streaming distill analysis
    func analyzeDistillStreaming(
        transcript: String,
        historicalContext: [HistoricalMemoContext]?,
        isPro: Bool,
        onProgress: @escaping @Sendable (AnalysisStreamingUpdate) -> Void
    ) async throws -> AnalyzeEnvelope<DistillData>
}
