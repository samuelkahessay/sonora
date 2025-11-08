@testable import Sonora
import XCTest

@MainActor
final class AnalyzeLiteDistillUseCaseTests: XCTestCase {

    // MARK: - Success Path Tests

    func test_execute_withValidTranscript_returnsLiteDistillEnvelope() async throws {
        // Given
        let memoId = UUID()
        let transcript = "Today I had a breakthrough moment while reflecting on my career path."

        let expectedData = LiteDistillData(
            summary: "You explored career reflections with optimism.",
            keyThemes: ["Career", "Growth"],
            personalInsight: PersonalInsight(
                type: .valueGlimpse,
                observation: "You lit up when discussing career growth.",
                invitation: "What excites you most about this path?"
            ),
            simpleTodos: [
                SimpleTodo(text: "Schedule career planning session", priority: .medium)
            ],
            reflectionQuestion: "What would success look like in six months?",
            closingNote: "You're building clarity about your path forward."
        )

        let expectedEnvelope = AnalyzeEnvelope(
            mode: .liteDistill,
            data: expectedData,
            model: "gpt-4o-mini",
            tokens: TokenUsage(input: 150, output: 100),
            latency_ms: 850,
            moderation: nil
        )

        let analysisService = MockAnalysisService(liteDistillResult: expectedEnvelope)
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let eventBus = NoopEventBus()
        let coordinator = OperationCoordinatorStub()

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When
        let result = try await sut.execute(transcript: transcript, memoId: memoId)

        // Then
        XCTAssertEqual(result.mode, .liteDistill)
        XCTAssertEqual(result.data.summary, expectedData.summary)
        XCTAssertEqual(result.data.keyThemes, expectedData.keyThemes)
        XCTAssertEqual(result.data.personalInsight.type, expectedData.personalInsight.type)
        XCTAssertEqual(result.data.simpleTodos.count, 1)
        XCTAssertEqual(result.data.reflectionQuestion, expectedData.reflectionQuestion)
        XCTAssertEqual(result.latency_ms, 850)
    }

    func test_execute_cacheHit_returnsCachedResultImmediately() async throws {
        // Given
        let memoId = UUID()
        let transcript = "This is cached content."

        let cachedData = LiteDistillData(
            summary: "Cached summary",
            keyThemes: ["Theme1"],
            personalInsight: PersonalInsight(
                type: .emotionalTone,
                observation: "Cached observation",
                invitation: nil
            ),
            simpleTodos: [],
            reflectionQuestion: "Cached question?",
            closingNote: "Cached note."
        )

        let cachedEnvelope = AnalyzeEnvelope(
            mode: .liteDistill,
            data: cachedData,
            model: "gpt-4o-mini",
            tokens: TokenUsage(input: 100, output: 50),
            latency_ms: 500,
            moderation: nil
        )

        let analysisService = MockAnalysisService(liteDistillResult: nil)
        let repository = InMemoryAnalysisRepositoryStub()
        repository.saveAnalysisResult(cachedEnvelope, for: memoId, mode: .liteDistill)

        let logger = CapturingLogger()
        let eventBus = NoopEventBus()
        let coordinator = OperationCoordinatorStub()

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When
        let result = try await sut.execute(transcript: transcript, memoId: memoId)

        // Then
        XCTAssertEqual(result.data.summary, "Cached summary")
        XCTAssertEqual(analysisService.apiCallCount, 0, "Should not call API when cache hit")

        // Verify cache hit was logged
        let cacheHitLogs = logger.entries.filter { $0.message == "LiteDistill.CacheHit" }
        XCTAssertEqual(cacheHitLogs.count, 1)
    }

    func test_execute_cacheMiss_callsAPIAndCachesResult() async throws {
        // Given
        let memoId = UUID()
        let transcript = "New content that needs analysis."

        let apiData = LiteDistillData(
            summary: "Fresh summary from API",
            keyThemes: ["Fresh"],
            personalInsight: PersonalInsight(
                type: .wordPattern,
                observation: "You said 'fresh' a lot.",
                invitation: nil
            ),
            simpleTodos: [],
            reflectionQuestion: "What's new?",
            closingNote: "Stay fresh."
        )

        let apiEnvelope = AnalyzeEnvelope(
            mode: .liteDistill,
            data: apiData,
            model: "gpt-4o-mini",
            tokens: TokenUsage(input: 120, output: 80),
            latency_ms: 900,
            moderation: nil
        )

        let analysisService = MockAnalysisService(liteDistillResult: apiEnvelope)
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let eventBus = NoopEventBus()
        let coordinator = OperationCoordinatorStub()

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When
        let result = try await sut.execute(transcript: transcript, memoId: memoId)

        // Then
        XCTAssertEqual(result.data.summary, "Fresh summary from API")
        XCTAssertEqual(analysisService.apiCallCount, 1)

        // Verify result was cached
        let cached: AnalyzeEnvelope<LiteDistillData>? = repository.getAnalysisResult(
            for: memoId,
            mode: .liteDistill,
            responseType: LiteDistillData.self
        )
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.data.summary, "Fresh summary from API")
    }

    // MARK: - Validation Tests

    func test_execute_withEmptyTranscript_throwsValidationError() async throws {
        // Given
        let memoId = UUID()
        let emptyTranscript = ""

        let analysisService = MockAnalysisService(liteDistillResult: nil)
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let eventBus = NoopEventBus()
        let coordinator = OperationCoordinatorStub()

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When/Then
        do {
            _ = try await sut.execute(transcript: emptyTranscript, memoId: memoId)
            XCTFail("Should throw validation error for empty transcript")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    func test_execute_withShortTranscript_throwsValidationError() async throws {
        // Given
        let memoId = UUID()
        let shortTranscript = "Hi"  // Less than 10 characters

        let analysisService = MockAnalysisService(liteDistillResult: nil)
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let eventBus = NoopEventBus()
        let coordinator = OperationCoordinatorStub()

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When/Then
        do {
            _ = try await sut.execute(transcript: shortTranscript, memoId: memoId)
            XCTFail("Should throw validation error for short transcript")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    func test_execute_withWhitespaceOnlyTranscript_throwsValidationError() async throws {
        // Given
        let memoId = UUID()
        let whitespaceTranscript = "     \n\t   "

        let analysisService = MockAnalysisService(liteDistillResult: nil)
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let eventBus = NoopEventBus()
        let coordinator = OperationCoordinatorStub()

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When/Then
        do {
            _ = try await sut.execute(transcript: whitespaceTranscript, memoId: memoId)
            XCTFail("Should throw validation error for whitespace-only transcript")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    // MARK: - Concurrency Tests

    func test_execute_whenSystemBusy_throwsOperationError() async throws {
        // Given
        let memoId = UUID()
        let transcript = "Valid transcript for testing concurrency"

        let analysisService = MockAnalysisService(liteDistillResult: nil)
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let eventBus = NoopEventBus()
        let coordinator = OperationCoordinatorStub(shouldRejectRegistration: true)

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When/Then
        do {
            _ = try await sut.execute(transcript: transcript, memoId: memoId)
            XCTFail("Should throw operation error when system is busy")
        } catch {
            // Expected error
            XCTAssertTrue(true)
        }
    }

    func test_execute_registersAndCompletesOperation() async throws {
        // Given
        let memoId = UUID()
        let transcript = "Testing operation lifecycle tracking"

        let data = LiteDistillData(
            summary: "Summary",
            keyThemes: [],
            personalInsight: PersonalInsight(
                type: .stoicMoment,
                observation: "Wisdom detected",
                invitation: nil
            ),
            simpleTodos: [],
            reflectionQuestion: "Reflect?",
            closingNote: "Note."
        )

        let envelope = AnalyzeEnvelope(
            mode: .liteDistill,
            data: data,
            model: "gpt-4o-mini",
            tokens: TokenUsage(input: 100, output: 50),
            latency_ms: 500,
            moderation: nil
        )

        let analysisService = MockAnalysisService(liteDistillResult: envelope)
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let eventBus = NoopEventBus()
        let coordinator = OperationCoordinatorStub()

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When
        _ = try await sut.execute(transcript: transcript, memoId: memoId)

        // Then
        XCTAssertEqual(coordinator.registeredOperations.count, 1)
        XCTAssertEqual(coordinator.completedOperations.count, 1)
        XCTAssertEqual(coordinator.failedOperations.count, 0)
    }

    // MARK: - Event Bus Tests

    func test_execute_onSuccess_publishesAnalysisCompletedEvent() async throws {
        // Given
        let memoId = UUID()
        let transcript = "Testing event publication"

        let data = LiteDistillData(
            summary: "Event test summary",
            keyThemes: [],
            personalInsight: PersonalInsight(
                type: .energyShift,
                observation: "Energy observed",
                invitation: nil
            ),
            simpleTodos: [],
            reflectionQuestion: "Energy?",
            closingNote: "Stay energized."
        )

        let envelope = AnalyzeEnvelope(
            mode: .liteDistill,
            data: data,
            model: "gpt-4o-mini",
            tokens: TokenUsage(input: 100, output: 50),
            latency_ms: 500,
            moderation: nil
        )

        let analysisService = MockAnalysisService(liteDistillResult: envelope)
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let eventBus = CapturingEventBus()
        let coordinator = OperationCoordinatorStub()

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When
        _ = try await sut.execute(transcript: transcript, memoId: memoId)

        // Then
        XCTAssertEqual(eventBus.publishedEvents.count, 1)

        guard case let .analysisCompleted(eventMemoId, mode, _) = eventBus.publishedEvents.first else {
            XCTFail("Expected analysisCompleted event")
            return
        }
        XCTAssertEqual(eventMemoId, memoId)
        XCTAssertEqual(mode, .liteDistill)
    }

    func test_execute_onFailure_doesNotPublishEvent() async throws {
        // Given
        let memoId = UUID()
        let transcript = "Testing failure without event"

        let analysisService = MockAnalysisService(
            liteDistillResult: nil,
            shouldThrowError: true
        )
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let eventBus = CapturingEventBus()
        let coordinator = OperationCoordinatorStub()

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When
        do {
            _ = try await sut.execute(transcript: transcript, memoId: memoId)
            XCTFail("Should throw error")
        } catch {
            // Expected error
        }

        // Then
        XCTAssertEqual(eventBus.publishedEvents.count, 0, "Should not publish event on failure")
    }

    // MARK: - Error Handling Tests

    func test_execute_networkError_propagatesErrorAndLogsIt() async throws {
        // Given
        let memoId = UUID()
        let transcript = "Testing network error handling"

        let analysisService = MockAnalysisService(
            liteDistillResult: nil,
            shouldThrowError: true
        )
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let eventBus = NoopEventBus()
        let coordinator = OperationCoordinatorStub()

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When/Then
        do {
            _ = try await sut.execute(transcript: transcript, memoId: memoId)
            XCTFail("Should propagate network error")
        } catch {
            // Verify error was logged
            let errorLogs = logger.entries.filter { $0.level == .error }
            XCTAssertGreaterThan(errorLogs.count, 0)
        }
    }

    func test_execute_apiError_clearsOperationAndThrows() async throws {
        // Given
        let memoId = UUID()
        let transcript = "Testing API error operation cleanup"

        let analysisService = MockAnalysisService(
            liteDistillResult: nil,
            shouldThrowError: true
        )
        let repository = InMemoryAnalysisRepositoryStub()
        let logger = CapturingLogger()
        let eventBus = NoopEventBus()
        let coordinator = OperationCoordinatorStub()

        let sut = AnalyzeLiteDistillUseCase(
            analysisService: analysisService,
            analysisRepository: repository,
            logger: logger,
            eventBus: eventBus,
            operationCoordinator: coordinator
        )

        // When/Then
        do {
            _ = try await sut.execute(transcript: transcript, memoId: memoId)
            XCTFail("Should throw API error")
        } catch {
            // Expected error
        }

        // Verify operation was marked as failed
        XCTAssertEqual(coordinator.failedOperations.count, 1)
        XCTAssertEqual(coordinator.completedOperations.count, 0)
    }
}

// MARK: - Test Doubles

@MainActor
private final class MockAnalysisService: ObservableObject, AnalysisServiceProtocol, @unchecked Sendable {
    private let liteDistillEnvelope: AnalyzeEnvelope<LiteDistillData>?
    private let shouldThrowError: Bool
    private(set) var apiCallCount = 0

    init(liteDistillResult: AnalyzeEnvelope<LiteDistillData>?, shouldThrowError: Bool = false) {
        self.liteDistillEnvelope = liteDistillResult
        self.shouldThrowError = shouldThrowError
    }

    func analyze<T>(mode: AnalysisMode, transcript: String, responseType: T.Type, historicalContext: [HistoricalMemoContext]?) async throws -> AnalyzeEnvelope<T> {
        fatalError("Use analyzeLiteDistill for this test")
    }

    func analyzeLiteDistill(transcript: String) async throws -> AnalyzeEnvelope<LiteDistillData> {
        apiCallCount += 1

        if shouldThrowError {
            throw NSError(domain: "TestError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mock API error"])
        }

        guard let envelope = liteDistillEnvelope else {
            fatalError("liteDistillEnvelope not set for mock")
        }

        return envelope
    }

    func analyzeDistill(transcript: String, historicalContext: [HistoricalMemoContext]?) async throws -> AnalyzeEnvelope<DistillData> { fatalError("Not stubbed") }
    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData> { fatalError("Not stubbed") }
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
private final class NoopEventBus: EventBusProtocol, @unchecked Sendable {
    func publish(_ event: AppEvent) {}
    func subscribe(to eventType: AppEvent.Type, subscriber: AnyObject?, handler: @escaping (AppEvent) -> Void) -> UUID { UUID() }
    func unsubscribe(_ subscriptionId: UUID) {}
    var subscriptionStats: String { "" }
}

@MainActor
private final class CapturingEventBus: EventBusProtocol, @unchecked Sendable {
    private(set) var publishedEvents: [AppEvent] = []

    func publish(_ event: AppEvent) {
        publishedEvents.append(event)
    }

    func subscribe(to eventType: AppEvent.Type, subscriber: AnyObject?, handler: @escaping (AppEvent) -> Void) -> UUID { UUID() }
    func unsubscribe(_ subscriptionId: UUID) {}
    var subscriptionStats: String { "" }
}

@MainActor
private final class OperationCoordinatorStub: OperationCoordinatorProtocol, @unchecked Sendable {
    private let shouldRejectRegistration: Bool
    private(set) var registeredOperations: [UUID] = []
    private(set) var completedOperations: [UUID] = []
    private(set) var failedOperations: [UUID] = []

    init(shouldRejectRegistration: Bool = false) {
        self.shouldRejectRegistration = shouldRejectRegistration
    }

    func setStatusDelegate(_ delegate: (any OperationStatusDelegate)?) {}

    func registerOperation(_ operationType: OperationType) async -> UUID? {
        if shouldRejectRegistration {
            return nil
        }
        let id = UUID()
        registeredOperations.append(id)
        return id
    }

    func startOperation(_ operationId: UUID) async -> Bool { true }

    func completeOperation(_ operationId: UUID) async {
        completedOperations.append(operationId)
    }

    func failOperation(_ operationId: UUID, errorDescription: String) async {
        failedOperations.append(operationId)
    }

    func cancelOperation(_ operationId: UUID) async {}
    func updateProgress(operationId: UUID, progress: OperationProgress) async {}
    func getOperationSummaries(group: OperationGroup, filter: OperationFilter, for memoId: UUID?) async -> [OperationSummary] { [] }
    func getSystemMetrics() async -> SystemOperationMetrics {
        SystemOperationMetrics(
            totalOperations: 0,
            activeOperations: 0,
            queuedOperations: 0,
            maxConcurrentOperations: 5,
            averageOperationDuration: nil
        )
    }
    func cancelAllOperations(for memoId: UUID) async -> Int { 0 }
    func cancelOperations(ofType category: OperationCategory) async -> Int { 0 }
    func cancelAllOperations() async -> Int { 0 }
    func isRecordingActive(for memoId: UUID) async -> Bool { false }
    func canStartTranscription(for memoId: UUID) async -> Bool { true }
    func getActiveOperations(for memoId: UUID) async -> [Sonora.Operation] { [] }
    func getAllActiveOperations() async -> [Sonora.Operation] { [] }
    func getQueuePosition(for operationId: UUID) async -> Int? { nil }
    func getDebugInfo() async -> String { "" }
    func getOperation(_ operationId: UUID) async -> Sonora.Operation? { nil }
}
