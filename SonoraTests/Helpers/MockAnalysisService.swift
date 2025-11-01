import Foundation
import Combine
@testable import Sonora

/// Mock implementation of AnalysisServiceProtocol for testing
/// Uses programmatic streaming simulation for testing SSE behavior
@MainActor
final class StreamingMockAnalysisService: ObservableObject, AnalysisServiceProtocol {

    // MARK: - Configuration

    /// Delay between interim streaming updates (in seconds)
    var streamingDelay: TimeInterval = 0.05

    /// Number of interim updates to send before final
    var interimUpdateCount: Int = 3

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

    func analyzeWithStreaming<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]?,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<T> {
        if shouldThrowError {
            throw errorToThrow ?? AnalysisError.networkError("Mock error")
        }

        guard !transcript.isEmpty else {
            throw AnalysisError.networkError("Empty transcript")
        }

        // Simulate streaming if progress handler provided
        if let progress = progress {
            await simulateStreaming(mode: mode, progress: progress)
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

    // MARK: - Pro-Tier Methods

    func analyzeCognitiveClarityCBT(transcript: String) async throws -> AnalyzeEnvelope<CognitiveClarityData> {
        try await analyze(mode: .cognitiveClarityCBT, transcript: transcript, responseType: CognitiveClarityData.self, historicalContext: nil)
    }

    func analyzePhilosophicalEchoes(transcript: String) async throws -> AnalyzeEnvelope<PhilosophicalEchoesData> {
        try await analyze(mode: .philosophicalEchoes, transcript: transcript, responseType: PhilosophicalEchoesData.self, historicalContext: nil)
    }

    func analyzeValuesRecognition(transcript: String) async throws -> AnalyzeEnvelope<ValuesRecognitionData> {
        try await analyze(mode: .valuesRecognition, transcript: transcript, responseType: ValuesRecognitionData.self, historicalContext: nil)
    }

    func analyzeLiteDistill(transcript: String) async throws -> AnalyzeEnvelope<LiteDistillData> {
        try await analyze(mode: .liteDistill, transcript: transcript, responseType: LiteDistillData.self, historicalContext: nil)
    }

    // MARK: - Streaming Variants

    func analyzeDistillSummaryStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<DistillSummaryData> {
        try await analyzeWithStreaming(
            mode: .distillSummary,
            transcript: transcript,
            responseType: DistillSummaryData.self,
            historicalContext: nil,
            progress: progress
        )
    }

    func analyzeDistillActionsStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<DistillActionsData> {
        try await analyzeWithStreaming(
            mode: .distillActions,
            transcript: transcript,
            responseType: DistillActionsData.self,
            historicalContext: nil,
            progress: progress
        )
    }

    func analyzeDistillReflectionStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        try await analyzeWithStreaming(
            mode: .distillReflection,
            transcript: transcript,
            responseType: DistillReflectionData.self,
            historicalContext: nil,
            progress: progress
        )
    }

    func analyzeCognitiveClarityCBTStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<CognitiveClarityData> {
        try await analyzeWithStreaming(
            mode: .cognitiveClarityCBT,
            transcript: transcript,
            responseType: CognitiveClarityData.self,
            historicalContext: nil,
            progress: progress
        )
    }

    func analyzePhilosophicalEchoesStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<PhilosophicalEchoesData> {
        try await analyzeWithStreaming(
            mode: .philosophicalEchoes,
            transcript: transcript,
            responseType: PhilosophicalEchoesData.self,
            historicalContext: nil,
            progress: progress
        )
    }

    func analyzeValuesRecognitionStreaming(
        transcript: String,
        progress: AnalysisStreamingHandler?
    ) async throws -> AnalyzeEnvelope<ValuesRecognitionData> {
        try await analyzeWithStreaming(
            mode: .valuesRecognition,
            transcript: transcript,
            responseType: ValuesRecognitionData.self,
            historicalContext: nil,
            progress: progress
        )
    }

    // MARK: - Helper Methods

    private func simulateStreaming(
        mode: AnalysisMode,
        progress: @escaping AnalysisStreamingHandler
    ) async {
        let fullText = getMockText(for: mode)
        let chunkSize = max(fullText.count / interimUpdateCount, 1)

        // Send interim updates
        for i in 1...interimUpdateCount {
            let endIndex = min(i * chunkSize, fullText.count)
            let partialText = String(fullText.prefix(endIndex))

            progress(AnalysisStreamingUpdate(partialText: partialText, isFinal: false))

            // Simulate network delay
            try? await Task.sleep(nanoseconds: UInt64(streamingDelay * 1_000_000_000))
        }

        // Send final update
        progress(AnalysisStreamingUpdate(partialText: fullText, isFinal: true))
    }

    private func getMockText(for mode: AnalysisMode) -> String {
        switch mode {
        case .distillSummary:
            return "Today was productive. Completed the report and scheduled a meeting with the team."
        case .distillActions:
            return "Email Sarah by Friday about the proposal. Call the client tomorrow at 2pm."
        case .distillReflection:
            return "What made this meeting particularly productive? How can you apply these lessons to future collaboration?"
        case .cognitiveClarityCBT:
            return "You mentioned 'I always mess things up' - this is an overgeneralization pattern. Consider: what are some things you've done well recently?"
        case .philosophicalEchoes:
            return "Your focus on what you can control echoes Stoic philosophy. As Epictetus said, 'Make the best use of what is in your power, and take the rest as it happens.'"
        case .valuesRecognition:
            return "Family and honesty appear as core values in your reflection. These priorities are guiding your decisions about work-life balance."
        default:
            return "Mock analysis result"
        }
    }

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

        case is CognitiveClarityData.Type:
            return CognitiveClarityData(
                cognitivePatterns: [
                    CognitivePattern(
                        type: .overgeneralization,
                        observation: "You mentioned 'I always mess things up'",
                        reframe: "What are some things you've done well recently?"
                    )
                ]
            ) as! T

        case is PhilosophicalEchoesData.Type:
            return PhilosophicalEchoesData(
                philosophicalEchoes: [
                    PhilosophicalEcho(
                        tradition: .stoicism,
                        connection: "Your focus on what you can control echoes Stoic philosophy",
                        quote: "Make the best use of what is in your power, and take the rest as it happens.",
                        source: "Epictetus"
                    )
                ]
            ) as! T

        case is ValuesRecognitionData.Type:
            return ValuesRecognitionData(
                coreValues: [
                    ValuesInsight.DetectedValue(
                        name: "Family",
                        evidence: "You mentioned family being most important",
                        confidence: 0.9
                    ),
                    ValuesInsight.DetectedValue(
                        name: "Honesty",
                        evidence: "You value honesty and integrity in relationships",
                        confidence: 0.85
                    )
                ],
                tensions: []
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
