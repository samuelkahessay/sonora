import Foundation

protocol AnalysisServiceProtocol: Sendable {
    // Base analyze method - implementations should provide default nil for historicalContext
    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]?
    ) async throws -> AnalyzeEnvelope<T>

    // Streaming variant - provides real-time updates as analysis generates
    func analyzeWithStreaming<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]?,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<T>

    // Convenience method for distill with historical context
    func analyzeDistill(
        transcript: String,
        historicalContext: [HistoricalMemoContext]?
    ) async throws -> AnalyzeEnvelope<DistillData>

    // Convenience method for distill without historical context (backward compatibility)
    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData>

    // Distill component methods for parallel processing
    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData>
    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData>
    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData>
    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData>

    // Pro-tier analysis methods for parallel processing
    func analyzeCognitiveClarityCBT(transcript: String) async throws -> AnalyzeEnvelope<CognitiveClarityData>
    func analyzePhilosophicalEchoes(transcript: String) async throws -> AnalyzeEnvelope<PhilosophicalEchoesData>
    func analyzeValuesRecognition(transcript: String) async throws -> AnalyzeEnvelope<ValuesRecognitionData>

    // Free tier lite distill
    func analyzeLiteDistill(transcript: String) async throws -> AnalyzeEnvelope<LiteDistillData>

    // MARK: - Streaming Wrapper Methods

    // Streaming variants for Distill components
    func analyzeDistillSummaryStreaming(transcript: String, progress: AnalysisStreamingHandler?) async throws -> AnalyzeEnvelope<DistillSummaryData>
    func analyzeDistillActionsStreaming(transcript: String, progress: AnalysisStreamingHandler?) async throws -> AnalyzeEnvelope<DistillActionsData>
    func analyzeDistillReflectionStreaming(transcript: String, progress: AnalysisStreamingHandler?) async throws -> AnalyzeEnvelope<DistillReflectionData>

    // Streaming variants for Pro-tier analysis
    func analyzeCognitiveClarityCBTStreaming(transcript: String, progress: AnalysisStreamingHandler?) async throws -> AnalyzeEnvelope<CognitiveClarityData>
    func analyzePhilosophicalEchoesStreaming(transcript: String, progress: AnalysisStreamingHandler?) async throws -> AnalyzeEnvelope<PhilosophicalEchoesData>
    func analyzeValuesRecognitionStreaming(transcript: String, progress: AnalysisStreamingHandler?) async throws -> AnalyzeEnvelope<ValuesRecognitionData>
}
