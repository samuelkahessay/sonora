import XCTest
@testable import Sonora

private final class FakeAnalysisService<T: Codable & Sendable>: ObservableObject, AnalysisServiceProtocol {
    let envelope: AnalyzeEnvelope<T>
    init(envelope: AnalyzeEnvelope<T>) { self.envelope = envelope }
    func analyze<U>(mode: AnalysisMode, transcript: String, responseType: U.Type) async throws -> AnalyzeEnvelope<U> where U: Sendable, U: Decodable, U: Encodable {
        // Force cast for test harness; only used with same T
        return envelope as! AnalyzeEnvelope<U>
    }
    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData> { fatalError() }
    func analyzeAnalysis(transcript: String) async throws -> AnalyzeEnvelope<AnalysisData> { fatalError() }
    func analyzeThemes(transcript: String) async throws -> AnalyzeEnvelope<ThemesData> { fatalError() }
    func analyzeTodos(transcript: String) async throws -> AnalyzeEnvelope<TodosData> { fatalError() }
    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData> { fatalError() }
    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData> { fatalError() }
    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData> { fatalError() }
    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData> { fatalError() }
}

final class ProgressiveAnalysisServiceTests: XCTestCase {
    func testEarlyTerminateOnSimpleContent() async throws {
        let data = DistillData(summary: "Short", action_items: nil, key_themes: [], reflection_questions: [])
        let env = AnalyzeEnvelope(mode: .distill, data: data, model: "tiny", tokens: TokenUsage(input: 10, output: 5), latency_ms: 50, moderation: nil)
        let tiny = FakeAnalysisService(envelope: env)
        let base = FakeAnalysisService(envelope: env)
        let svc = ProgressiveAnalysisService(tiny: tiny, base: base)
        let out: AnalyzeEnvelope<DistillData> = try await svc.analyze(mode: .distill, transcript: "Short text", responseType: DistillData.self)
        XCTAssertEqual(out.model, "tiny")
    }
}
