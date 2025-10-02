@testable import Sonora
import XCTest

@MainActor
final class DetectEventsAndRemindersUseCaseTests: XCTestCase {
    func testLogsNearMissesWithinMargin() async throws {
        let memoId = UUID()
        let transcript = "We should sync with design next Wednesday around lunch. Also send the final deck to Alex tomorrow morning."

        let acceptedEvent = EventsData.DetectedEvent(
            id: "evt-accepted",
            title: "Quarterly review",
            startDate: Date(timeIntervalSince1970: 1_708_012_800),
            endDate: Date(timeIntervalSince1970: 1_708_016_000),
            location: "HQ",
            participants: ["Ops"],
            confidence: 0.92,
            sourceText: "Quarterly review on Wednesday at noon",
            memoId: memoId
        )

        let nearMissEvent = EventsData.DetectedEvent(
            id: "evt-near",
            title: "Design sync",
            startDate: Date(timeIntervalSince1970: 1_708_099_200),
            endDate: nil,
            location: "Design Lab",
            participants: ["Design"],
            confidence: 0.63,
            sourceText: "Let us catch up with design next Wednesday around lunch",
            memoId: memoId
        )

        let eventsData = EventsData(events: [acceptedEvent, nearMissEvent])

        let acceptedReminder = RemindersData.DetectedReminder(
            id: "rem-accepted",
            title: "Send final deck",
            dueDate: Date(timeIntervalSince1970: 1_708_056_000),
            priority: .high,
            confidence: 0.81,
            sourceText: "Send the final deck to Alex tomorrow morning",
            memoId: memoId
        )

        let nearMissReminder = RemindersData.DetectedReminder(
            id: "rem-near",
            title: "Draft recap notes",
            dueDate: Date(timeIntervalSince1970: 1_708_142_400),
            priority: .medium,
            confidence: 0.58,
            sourceText: "Probably draft recap notes next week",
            memoId: memoId
        )

        let remindersData = RemindersData(reminders: [acceptedReminder, nearMissReminder])

        let analysisService = StubAnalysisService(eventsData: eventsData, remindersData: remindersData)
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let bus = NoopEventBus()
        let coordinator = OperationCoordinatorStub()
        let thresholds = FixedThresholdPolicy(eventThreshold: 0.70, reminderThreshold: 0.65)

        let sut = DetectEventsAndRemindersUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: bus,
            operationCoordinator: coordinator,
            thresholdPolicy: thresholds
        )

        _ = try await sut.execute(transcript: transcript, memoId: memoId)

        let nearMissLogs = logger.entries.filter { $0.message == "Detection.NearMiss" && $0.category == .detection }
        XCTAssertEqual(nearMissLogs.count, 2)

        let eventsLog = try XCTUnwrap(nearMissLogs.first { valueAsString($0.context?.additionalInfo?["mode"]) == "events" })
        XCTAssertEqual(valueAsInt(eventsLog.context?.additionalInfo?["candidateCount"]), 1)
        let eventCandidates = eventsLog.context?.additionalInfo?["candidates"] as? [[String: Any]]
        let eventCandidate = try XCTUnwrap(eventCandidates?.first)
        XCTAssertEqual(eventCandidate["title"] as? String, nearMissEvent.title)
        XCTAssertEqual(eventCandidate["sourceText"] as? String, nearMissEvent.sourceText)
        XCTAssertEqual(valueAsDouble(eventCandidate["confidence"]), Double(nearMissEvent.confidence), accuracy: 0.001)
        XCTAssertGreaterThan(valueAsDouble(eventCandidate["delta"]), 0)

        let remindersLog = try XCTUnwrap(nearMissLogs.first { valueAsString($0.context?.additionalInfo?["mode"]) == "reminders" })
        XCTAssertEqual(valueAsInt(remindersLog.context?.additionalInfo?["candidateCount"]), 1)
        let reminderCandidates = remindersLog.context?.additionalInfo?["candidates"] as? [[String: Any]]
        let reminderCandidate = try XCTUnwrap(reminderCandidates?.first)
        XCTAssertEqual(reminderCandidate["title"] as? String, nearMissReminder.title)
        XCTAssertEqual(reminderCandidate["sourceText"] as? String, nearMissReminder.sourceText)
        XCTAssertEqual(valueAsDouble(reminderCandidate["confidence"]), Double(nearMissReminder.confidence), accuracy: 0.001)
        XCTAssertEqual(reminderCandidate["dueDate"] as? String, isoString(nearMissReminder.dueDate))
    }

    func testFallbackSelectsTopCandidatesWhenNonePassThreshold() async throws {
        let memoId = UUID()
        let transcript = "Scheduling notes with weak confidence"

        // None meet strict threshold (0.80), but fallback should include >= max(0.40, t-0.25)=0.55
        let e1 = EventsData.DetectedEvent(
            id: "e1", title: "Discuss roadmap", startDate: Date(), endDate: nil, location: nil, participants: ["P1"], confidence: 0.62, sourceText: "roadmap", memoId: memoId
        )
        let e2 = EventsData.DetectedEvent(
            id: "e2", title: "Sync", startDate: Date(), endDate: nil, location: nil, participants: ["P2"], confidence: 0.61, sourceText: "sync", memoId: memoId
        )
        let e3 = EventsData.DetectedEvent(
            id: "e3", title: "Standup", startDate: Date(), endDate: nil, location: nil, participants: ["P3"], confidence: 0.58, sourceText: "standup", memoId: memoId
        )
        let eventsData = EventsData(events: [e1, e2, e3])

        let r1 = RemindersData.DetectedReminder(
            id: "r1", title: "Email Alice", dueDate: nil, priority: .medium, confidence: 0.62, sourceText: "email", memoId: memoId
        )
        let r2 = RemindersData.DetectedReminder(
            id: "r2", title: "Write notes", dueDate: nil, priority: .low, confidence: 0.57, sourceText: "notes", memoId: memoId
        )
        let r3 = RemindersData.DetectedReminder(
            id: "r3", title: "Book room", dueDate: nil, priority: .high, confidence: 0.56, sourceText: "book", memoId: memoId
        )
        let remindersData = RemindersData(reminders: [r1, r2, r3])

        let analysisService = StubAnalysisService(eventsData: eventsData, remindersData: remindersData)
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let bus = NoopEventBus()
        let coordinator = OperationCoordinatorStub()
        let thresholds = FixedThresholdPolicy(eventThreshold: 0.80, reminderThreshold: 0.80)

        let sut = DetectEventsAndRemindersUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: bus,
            operationCoordinator: coordinator,
            thresholdPolicy: thresholds
        )

        let result = try await sut.execute(transcript: transcript, memoId: memoId)

        // Events fallback picks top 2 by confidence >= 0.55
        XCTAssertEqual(result.events?.events.count, 2)
        let eventIds = Set(result.events!.events.map { $0.id })
        XCTAssertTrue(eventIds.contains("e1"))
        XCTAssertTrue(eventIds.contains("e2"))

        // Reminders fallback picks top 3 by confidence >= 0.55
        XCTAssertEqual(result.reminders?.reminders.count, 3)
        let reminderIds = Set(result.reminders!.reminders.map { $0.id })
        XCTAssertEqual(reminderIds, Set(["r1", "r2", "r3"]))
    }
}

// MARK: - Helpers

@MainActor
private final class CapturingLogger: LoggerProtocol, @unchecked Sendable {
    struct Entry {
        let level: LogLevel
        let category: LogCategory
        let message: String
        let context: LogContext?
    }

    private(set) var entries: [Entry] = []

    func log(level: LogLevel, category: LogCategory, message: String, context: LogContext?, error: Error?) {
        entries.append(Entry(level: level, category: category, message: message, context: context))
    }

    func verbose(_ message: String, category: LogCategory, context: LogContext?) {
        log(level: .verbose, category: category, message: message, context: context, error: nil)
    }

    func debug(_ message: String, category: LogCategory, context: LogContext?) {
        log(level: .debug, category: category, message: message, context: context, error: nil)
    }

    func info(_ message: String, category: LogCategory, context: LogContext?) {
        log(level: .info, category: category, message: message, context: context, error: nil)
    }

    func warning(_ message: String, category: LogCategory, context: LogContext?, error: Error?) {
        log(level: .warning, category: category, message: message, context: context, error: error)
    }

    func error(_ message: String, category: LogCategory, context: LogContext?, error: Error?) {
        log(level: .error, category: category, message: message, context: context, error: error)
    }

    func critical(_ message: String, category: LogCategory, context: LogContext?, error: Error?) {
        log(level: .critical, category: category, message: message, context: context, error: error)
    }
}

@MainActor
private final class StubAnalysisService: ObservableObject, AnalysisServiceProtocol, @unchecked Sendable {
    private let eventsEnvelope: AnalyzeEnvelope<EventsData>
    private let remindersEnvelope: AnalyzeEnvelope<RemindersData>

    init(eventsData: EventsData, remindersData: RemindersData) {
        eventsEnvelope = AnalyzeEnvelope(
            mode: .events,
            data: eventsData,
            model: "test",
            tokens: TokenUsage(input: 0, output: 0),
            latency_ms: 0,
            moderation: nil
        )
        remindersEnvelope = AnalyzeEnvelope(
            mode: .reminders,
            data: remindersData,
            model: "test",
            tokens: TokenUsage(input: 0, output: 0),
            latency_ms: 0,
            moderation: nil
        )
    }

    func analyze<T>(mode: AnalysisMode, transcript: String, responseType: T.Type) async throws -> AnalyzeEnvelope<T> {
        switch mode {
        case .events:
            guard let data = eventsEnvelope.data as? T else { fatalError("Unexpected response type") }
            return AnalyzeEnvelope(mode: .events, data: data, model: eventsEnvelope.model, tokens: eventsEnvelope.tokens, latency_ms: eventsEnvelope.latency_ms, moderation: nil)
        case .reminders:
            guard let data = remindersEnvelope.data as? T else { fatalError("Unexpected response type") }
            return AnalyzeEnvelope(mode: .reminders, data: data, model: remindersEnvelope.model, tokens: remindersEnvelope.tokens, latency_ms: remindersEnvelope.latency_ms, moderation: nil)
        default:
            fatalError("Mode not stubbed")
        }
    }

    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData> { fatalError("Not stubbed") }
    func analyzeAnalysis(transcript: String) async throws -> AnalyzeEnvelope<AnalysisData> { fatalError("Not stubbed") }
    func analyzeThemes(transcript: String) async throws -> AnalyzeEnvelope<ThemesData> { fatalError("Not stubbed") }
    func analyzeTodos(transcript: String) async throws -> AnalyzeEnvelope<TodosData> { fatalError("Not stubbed") }
    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData> { fatalError("Not stubbed") }
    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData> { fatalError("Not stubbed") }
    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData> { fatalError("Not stubbed") }
    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData> { fatalError("Not stubbed") }
}

@MainActor
private final class InMemoryAnalysisRepositoryStub: AnalysisRepository {
    private var storage: [UUID: [AnalysisMode: Any]] = [:]

    func saveAnalysisResult<T>(_ result: AnalyzeEnvelope<T>, for memoId: UUID, mode: AnalysisMode) {
        var memoStorage = storage[memoId] ?? [:]
        memoStorage[mode] = result
        storage[memoId] = memoStorage
    }

    func getAnalysisResult<T>(for memoId: UUID, mode: AnalysisMode, responseType: T.Type) -> AnalyzeEnvelope<T>? {
        guard let memoStorage = storage[memoId], let envelope = memoStorage[mode] as? AnalyzeEnvelope<T> else {
            return nil
        }
        return envelope
    }

    func hasAnalysisResult(for memoId: UUID, mode: AnalysisMode) -> Bool {
        storage[memoId]?[mode] != nil
    }

    func deleteAnalysisResults(for memoId: UUID) {
        storage[memoId] = nil
    }

    func deleteAnalysisResult(for memoId: UUID, mode: AnalysisMode) {
        storage[memoId]?[mode] = nil
    }

    func getAllAnalysisResults(for memoId: UUID) -> [AnalysisMode: Any] {
        storage[memoId] ?? [:]
    }

    func clearCache() {
        storage.removeAll()
    }

    func getCacheSize() -> Int {
        storage.reduce(0) { $0 + $1.value.count }
    }

    func getAnalysisHistory(for memoId: UUID) -> [(mode: AnalysisMode, timestamp: Date)] {
        []
    }
}

@MainActor
private final class NoopEventBus: EventBusProtocol, @unchecked Sendable {
    func publish(_ event: AppEvent) {}
    func subscribe(to eventType: AppEvent.Type, subscriber: AnyObject?, handler: @escaping (AppEvent) -> Void) -> UUID { UUID() }
    func unsubscribe(_ subscriptionId: UUID) {}
    var subscriptionStats: String { "" }
}

@MainActor
private final class OperationCoordinatorStub: OperationCoordinatorProtocol, @unchecked Sendable {
    func setStatusDelegate(_ delegate: (any OperationStatusDelegate)?) {}

    func registerOperation(_ operationType: OperationType) async -> UUID? { UUID() }
    func startOperation(_ operationId: UUID) async -> Bool { true }
    func completeOperation(_ operationId: UUID) async {}
    func failOperation(_ operationId: UUID, errorDescription: String) async {}
    func cancelOperation(_ operationId: UUID) async {}
    func updateProgress(operationId: UUID, progress: OperationProgress) async {}

    func cancelAllOperations(for memoId: UUID) async -> Int { 0 }
    func cancelOperations(ofType category: OperationCategory) async -> Int { 0 }
    func cancelAllOperations() async -> Int { 0 }

    func isRecordingActive(for memoId: UUID) async -> Bool { false }
    func canStartTranscription(for memoId: UUID) async -> Bool { true }
    func getActiveOperations(for memoId: UUID) async -> [Sonora.Operation] { [] }
    func getAllActiveOperations() async -> [Sonora.Operation] { [] }
    func getSystemMetrics() async -> SystemOperationMetrics {
        SystemOperationMetrics(
            totalOperations: 0,
            activeOperations: 0,
            queuedOperations: 0,
            maxConcurrentOperations: 1,
            averageOperationDuration: nil
        )
    }
    func getOperationSummaries(group: OperationGroup, filter: OperationFilter, for memoId: UUID?) async -> [OperationSummary] { [] }
    func getQueuePosition(for operationId: UUID) async -> Int? { nil }
    func getDebugInfo() async -> String { "" }
    func getOperation(_ operationId: UUID) async -> Sonora.Operation? { nil }
}

private struct FixedThresholdPolicy: AdaptiveThresholdPolicy {
    let eventThreshold: Float
    let reminderThreshold: Float

    func thresholds(for context: DetectionContext) -> (event: Float, reminder: Float) {
        (eventThreshold, reminderThreshold)
    }
}

private func isoString(_ date: Date?) -> String? {
    guard let date = date else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
}

private func valueAsString(_ value: Any?) -> String? {
    switch value {
    case let string as String:
        return string
    case let number as NSNumber:
        return number.stringValue
    default:
        return nil
    }
}

private func valueAsInt(_ value: Any?) -> Int {
    switch value {
    case let int as Int:
        return int
    case let number as NSNumber:
        return number.intValue
    default:
        return 0
    }
}

private func valueAsDouble(_ value: Any?) -> Double {
    switch value {
    case let double as Double:
        return double
    case let float as Float:
        return Double(float)
    case let number as NSNumber:
        return number.doubleValue
    default:
        return 0
    }
}
