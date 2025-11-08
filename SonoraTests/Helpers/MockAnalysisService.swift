import Foundation
@testable import Sonora

/// Mock implementation of AnalysisServiceProtocol for testing
@MainActor
final class MockAnalysisService: AnalysisServiceProtocol {

    // MARK: - Configuration

    /// Whether to simulate errors
    var shouldThrowError: Bool = false
    var errorToThrow: Error?

    // MARK: - AnalysisServiceProtocol Implementation

    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]?
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
        historicalContext: [HistoricalMemoContext]?
    ) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyze(
            mode: .distill,
            transcript: transcript,
            responseType: DistillData.self,
            historicalContext: historicalContext
        )
    }

    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyzeDistill(transcript: transcript, historicalContext: nil)
    }

    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData> {
        try await analyze(mode: .distillSummary, transcript: transcript, responseType: DistillSummaryData.self, historicalContext: nil)
    }

    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData> {
        try await analyze(mode: .distillActions, transcript: transcript, responseType: DistillActionsData.self, historicalContext: nil)
    }

    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData> {
        try await analyze(mode: .distillThemes, transcript: transcript, responseType: DistillThemesData.self, historicalContext: nil)
    }

    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        try await analyze(mode: .distillReflection, transcript: transcript, responseType: DistillReflectionData.self, historicalContext: nil)
    }

    func analyzeLiteDistill(transcript: String) async throws -> AnalyzeEnvelope<LiteDistillData> {
        try await analyze(mode: .liteDistill, transcript: transcript, responseType: LiteDistillData.self, historicalContext: nil)
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
                key_themes: ["Productivity", "Collaboration", "Time management"]
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
