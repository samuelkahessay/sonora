import Foundation

struct AnalysisRequestContext: Sendable {
    let correlationId: String
    let memoId: UUID?
}

protocol AnalysisServiceProtocol: Sendable {
    // Base analyze method - implementations should provide default nil for historicalContext
    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]?,
        context: AnalysisRequestContext?
    ) async throws -> AnalyzeEnvelope<T>

    // Convenience method for distill with historical context
    func analyzeDistill(
        transcript: String,
        historicalContext: [HistoricalMemoContext]?,
        context: AnalysisRequestContext?
    ) async throws -> AnalyzeEnvelope<DistillData>

    // Convenience method for distill without historical context (backward compatibility)
    func analyzeDistill(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillData>

    // Distill component methods for parallel processing
    func analyzeDistillSummary(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillSummaryData>
    func analyzeDistillThemes(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillThemesData>
    func analyzeDistillPersonalInsight(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillPersonalInsightData>
    func analyzeDistillActions(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillActionsData>
    func analyzeDistillReflection(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillReflectionData>
    func analyzeDistillClosingNote(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillClosingNoteData>

    // Free tier lite distill
    func analyzeLiteDistill(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<LiteDistillData>
}

extension AnalysisServiceProtocol {
    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]? = nil
    ) async throws -> AnalyzeEnvelope<T> {
        try await analyze(
            mode: mode,
            transcript: transcript,
            responseType: responseType,
            historicalContext: historicalContext,
            context: nil
        )
    }

    func analyzeDistill(
        transcript: String,
        historicalContext: [HistoricalMemoContext]? = nil
    ) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyzeDistill(transcript: transcript, historicalContext: historicalContext, context: nil)
    }

    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyzeDistill(transcript: transcript, context: nil)
    }

    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData> {
        try await analyzeDistillSummary(transcript: transcript, context: nil)
    }

    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData> {
        try await analyzeDistillThemes(transcript: transcript, context: nil)
    }

    func analyzeDistillPersonalInsight(transcript: String) async throws -> AnalyzeEnvelope<DistillPersonalInsightData> {
        try await analyzeDistillPersonalInsight(transcript: transcript, context: nil)
    }

    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData> {
        try await analyzeDistillActions(transcript: transcript, context: nil)
    }

    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        try await analyzeDistillReflection(transcript: transcript, context: nil)
    }

    func analyzeDistillClosingNote(transcript: String) async throws -> AnalyzeEnvelope<DistillClosingNoteData> {
        try await analyzeDistillClosingNote(transcript: transcript, context: nil)
    }

    func analyzeLiteDistill(transcript: String) async throws -> AnalyzeEnvelope<LiteDistillData> {
        try await analyzeLiteDistill(transcript: transcript, context: nil)
    }
}
