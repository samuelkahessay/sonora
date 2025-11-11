import Foundation
@testable import Sonora

/// Mock implementation of AnalysisServiceProtocol for testing
@MainActor
final class MockAnalysisService: AnalysisServiceProtocol {

    // MARK: - Configuration

    /// Whether to simulate errors
    var shouldThrowError: Bool = false
    var errorToThrow: Error?

    /// Track API call counts for verification in tests
    private(set) var apiCallCount = 0

    /// Optional pre-configured envelope for liteDistill (for test-specific results)
    var liteDistillEnvelope: AnalyzeEnvelope<LiteDistillData>?

    // MARK: - AnalysisServiceProtocol Implementation

    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]?,
        context: AnalysisRequestContext?
    ) async throws -> AnalyzeEnvelope<T> {
        if shouldThrowError {
            throw errorToThrow ?? AnalysisError.networkError("Mock error")
        }

        guard !transcript.isEmpty else {
            throw AnalysisError.networkError("Empty transcript")
        }

        return createMockEnvelope(mode: mode, responseType: responseType)
    }

    // MARK: - Distill Methods

    func analyzeDistill(
        transcript: String,
        historicalContext: [HistoricalMemoContext]?,
        context: AnalysisRequestContext?
    ) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyze(
            mode: .distill,
            transcript: transcript,
            responseType: DistillData.self,
            historicalContext: historicalContext,
            context: context
        )
    }

    func analyzeDistill(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyzeDistill(transcript: transcript, historicalContext: nil, context: context)
    }

    func analyzeDistillSummary(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillSummaryData> {
        try await analyze(mode: .distillSummary, transcript: transcript, responseType: DistillSummaryData.self, historicalContext: nil, context: context)
    }

    func analyzeDistillActions(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillActionsData> {
        try await analyze(mode: .distillActions, transcript: transcript, responseType: DistillActionsData.self, historicalContext: nil, context: context)
    }

    func analyzeDistillThemes(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillThemesData> {
        try await analyze(mode: .distillThemes, transcript: transcript, responseType: DistillThemesData.self, historicalContext: nil, context: context)
    }

    func analyzeDistillPersonalInsight(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillPersonalInsightData> {
        try await analyze(mode: .distillPersonalInsight, transcript: transcript, responseType: DistillPersonalInsightData.self, historicalContext: nil, context: context)
    }

    func analyzeDistillReflection(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        try await analyze(mode: .distillReflection, transcript: transcript, responseType: DistillReflectionData.self, historicalContext: nil, context: context)
    }

    func analyzeDistillClosingNote(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<DistillClosingNoteData> {
        try await analyze(mode: .distillClosingNote, transcript: transcript, responseType: DistillClosingNoteData.self, historicalContext: nil, context: context)
    }

    func analyzeLiteDistill(transcript: String, context: AnalysisRequestContext?) async throws -> AnalyzeEnvelope<LiteDistillData> {
        apiCallCount += 1

        // If a pre-configured envelope is set, return it (for test-specific scenarios)
        if let envelope = liteDistillEnvelope {
            if shouldThrowError {
                throw errorToThrow ?? AnalysisError.networkError("Mock error")
            }
            return envelope
        }

        // Otherwise use default mock generation
        return try await analyze(mode: .liteDistill, transcript: transcript, responseType: LiteDistillData.self, historicalContext: nil, context: context)
    }

    // MARK: - Helper Methods

    private func createMockEnvelope<T: Codable & Sendable>(
        mode: AnalysisMode,
        responseType: T.Type
    ) -> AnalyzeEnvelope<T> {
        let data = createMockData(for: responseType)

        return AnalyzeEnvelope(
            mode: mode,
            data: data,
            model: "mock-model",
            tokens: TokenUsage(input: 100, output: 50),
            latency_ms: 100,
            moderation: nil
        )
    }

    private func createMockData<T: Codable & Sendable>(for type: T.Type) -> T {
        switch type {
        case is DistillSummaryData.Type:
            return DistillSummaryData(
                summary: "Today was productive. Completed the report and scheduled a meeting with the team."
            ) as! T

        case is DistillActionsData.Type:
            return DistillActionsData(
                action_items: [
                    DistillData.ActionItem(text: "Email Sarah by Friday", priority: .high),
                    DistillData.ActionItem(text: "Call client at 2pm tomorrow", priority: .medium)
                ]
            ) as! T

        case is DistillReflectionData.Type:
            return DistillReflectionData(
                reflection_questions: [
                    "What made this meeting particularly productive?",
                    "How can you apply these lessons to future collaboration?"
                ]
            ) as! T

        case is DistillThemesData.Type:
            return DistillThemesData(
                keyThemes: ["Productivity", "Collaboration", "Time management"]
            ) as! T

        case is DistillPersonalInsightData.Type:
            return DistillPersonalInsightData(
                personalInsight: PersonalInsight(
                    type: .emotionalTone,
                    observation: "You seem energized when collaborating",
                    invitation: "Consider scheduling more team activities"
                )
            ) as! T

        case is DistillClosingNoteData.Type:
            return DistillClosingNoteData(
                closingNote: "Keep up the great work!"
            ) as! T

        case is DistillData.Type:
            return DistillData(
                summary: "Mock distill summary",
                action_items: [],
                reflection_questions: ["Mock question?"],
                patterns: nil,
                events: nil,
                reminders: nil
            ) as! T

        case is LiteDistillData.Type:
            return LiteDistillData(
                summary: "Mock lite distill summary",
                keyThemes: ["Theme 1", "Theme 2"],
                personalInsight: PersonalInsight(
                    type: .emotionalTone,
                    observation: "You seem energized when collaborating",
                    invitation: "Consider scheduling more team activities"
                ),
                simpleTodos: [],
                reflectionQuestion: "What energizes you most?",
                closingNote: "Keep up the great work!"
            ) as! T

        default:
            fatalError("Unsupported mock data type: \(type)")
        }
    }
}
