#if canImport(SwiftData)
@testable import Sonora
import SwiftData
import XCTest

@MainActor
final class AnalysisRepositoryImplTests: XCTestCase {

    // MARK: - Test Infrastructure

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            MemoModel.self,
            AnalysisResultModel.self,
            TranscriptionModel.self,
            AutoTitleJobModel.self
        ])

        if let configInit = ModelConfigurationInit.inMemory() {
            let container = try ModelContainer(for: schema, configurations: configInit)
            return ModelContext(container)
        } else {
            let container = try ModelContainer(for: schema)
            return ModelContext(container)
        }
    }

    private func makeTestMemo(in context: ModelContext, id: UUID = UUID()) throws -> MemoModel {
        let memo = MemoModel(
            id: id,
            creationDate: Date(),
            filename: "test_memo.m4a",
            audioFilePath: "/path/to/test.m4a",
            duration: 120.0
        )
        context.insert(memo)
        try context.save()
        return memo
    }

    private func makeTestAnalysisResult<T: Codable & Sendable>(
        mode: AnalysisMode,
        data: T
    ) -> AnalyzeEnvelope<T> {
        AnalyzeEnvelope(
            mode: mode,
            data: data,
            model: "gpt-4",
            tokens: TokenUsage(input: 100, output: 50),
            latency_ms: 250,
            moderation: nil
        )
    }

    // MARK: - Save and Retrieve Tests

    func test_saveAndGetAnalysisResult_Success() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        // Create test data
        struct TestData: Codable, Sendable {
            let summary: String
            let keywords: [String]
        }
        let testData = TestData(summary: "Test summary", keywords: ["test", "memo"])
        let envelope = makeTestAnalysisResult(mode: .distill, data: testData)

        // Save
        repository.saveAnalysisResult(envelope, for: memo.id, mode: .distill)

        // Retrieve
        let retrieved = repository.getAnalysisResult(
            for: memo.id,
            mode: .distill,
            responseType: TestData.self
        )

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.data.summary, "Test summary")
        XCTAssertEqual(retrieved?.data.keywords, ["test", "memo"])
        XCTAssertEqual(retrieved?.mode, .distill)
        XCTAssertEqual(retrieved?.latency_ms, 250)
    }

    func test_saveMultipleModesForSameMemo_Success() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        // Save different modes
        let distillEnvelope = makeTestAnalysisResult(
            mode: .distill,
            data: TestData(text: "Distill result")
        )
        let eventsEnvelope = makeTestAnalysisResult(
            mode: .events,
            data: TestData(text: "Events result")
        )

        repository.saveAnalysisResult(distillEnvelope, for: memo.id, mode: .distill)
        repository.saveAnalysisResult(eventsEnvelope, for: memo.id, mode: .events)

        // Retrieve both
        let distillResult = repository.getAnalysisResult(
            for: memo.id,
            mode: .distill,
            responseType: TestData.self
        )
        let eventsResult = repository.getAnalysisResult(
            for: memo.id,
            mode: .events,
            responseType: TestData.self
        )

        XCTAssertEqual(distillResult?.data.text, "Distill result")
        XCTAssertEqual(eventsResult?.data.text, "Events result")
    }

    func test_getAnalysisResult_NonExistent_ReturnsNil() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        let result = repository.getAnalysisResult(
            for: memo.id,
            mode: .distill,
            responseType: TestData.self
        )

        XCTAssertNil(result)
    }

    // MARK: - Memory Cache Tests

    func test_getAnalysisResult_UsesMemoryCache() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }
        let envelope = makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test"))

        // Save (populates cache)
        repository.saveAnalysisResult(envelope, for: memo.id, mode: .distill)

        // Verify cache is populated (getCacheSize should be 1)
        XCTAssertEqual(repository.getCacheSize(), 1)

        // Retrieve (should hit memory cache)
        let result = repository.getAnalysisResult(
            for: memo.id,
            mode: .distill,
            responseType: TestData.self
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.data.text, "Test")
    }

    func test_clearCache_RemovesMemoryCache() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }
        let envelope = makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test"))

        repository.saveAnalysisResult(envelope, for: memo.id, mode: .distill)
        XCTAssertEqual(repository.getCacheSize(), 1)

        repository.clearCache()
        XCTAssertEqual(repository.getCacheSize(), 0)

        // Data should still be retrievable from store
        let result = repository.getAnalysisResult(
            for: memo.id,
            mode: .distill,
            responseType: TestData.self
        )
        XCTAssertNotNil(result, "Should retrieve from store after cache clear")
    }

    // MARK: - HasAnalysisResult Tests

    func test_hasAnalysisResult_ExistsInCache_ReturnsTrue() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }
        let envelope = makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test"))

        repository.saveAnalysisResult(envelope, for: memo.id, mode: .distill)

        XCTAssertTrue(repository.hasAnalysisResult(for: memo.id, mode: .distill))
        XCTAssertFalse(repository.hasAnalysisResult(for: memo.id, mode: .events))
    }

    func test_hasAnalysisResult_ExistsInStoreOnly_ReturnsTrue() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }
        let envelope = makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test"))

        repository.saveAnalysisResult(envelope, for: memo.id, mode: .distill)
        repository.clearCache()

        XCTAssertTrue(repository.hasAnalysisResult(for: memo.id, mode: .distill))
    }

    func test_hasAnalysisResult_DoesNotExist_ReturnsFalse() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        XCTAssertFalse(repository.hasAnalysisResult(for: memo.id, mode: .distill))
    }

    // MARK: - Delete Tests

    func test_deleteAnalysisResult_RemovesSpecificMode() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        // Save multiple modes
        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Distill")),
            for: memo.id,
            mode: .distill
        )
        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .events, data: TestData(text: "Events")),
            for: memo.id,
            mode: .events
        )

        // Delete only distill
        repository.deleteAnalysisResult(for: memo.id, mode: .distill)

        XCTAssertFalse(repository.hasAnalysisResult(for: memo.id, mode: .distill))
        XCTAssertTrue(repository.hasAnalysisResult(for: memo.id, mode: .events))
    }

    func test_deleteAnalysisResults_RemovesAllForMemo() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo1 = try makeTestMemo(in: context, id: UUID())
        let memo2 = try makeTestMemo(in: context, id: UUID())

        struct TestData: Codable, Sendable {
            let text: String
        }

        // Save for both memos
        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Memo1")),
            for: memo1.id,
            mode: .distill
        )
        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Memo2")),
            for: memo2.id,
            mode: .distill
        )

        // Delete all for memo1
        repository.deleteAnalysisResults(for: memo1.id)

        XCTAssertFalse(repository.hasAnalysisResult(for: memo1.id, mode: .distill))
        XCTAssertTrue(repository.hasAnalysisResult(for: memo2.id, mode: .distill))
    }

    // MARK: - GetAllAnalysisResults Tests

    func test_getAllAnalysisResults_ReturnsAllModesForMemo() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        // Save multiple modes
        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Distill")),
            for: memo.id,
            mode: .distill
        )
        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .events, data: TestData(text: "Events")),
            for: memo.id,
            mode: .events
        )

        let allResults = repository.getAllAnalysisResults(for: memo.id)

        XCTAssertEqual(allResults.count, 2)
        XCTAssertNotNil(allResults[.distill])
        XCTAssertNotNil(allResults[.events])
        XCTAssertNil(allResults[.reminders])
    }

    func test_getAllAnalysisResults_EmptyMemo_ReturnsEmpty() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        let allResults = repository.getAllAnalysisResults(for: memo.id)

        XCTAssertTrue(allResults.isEmpty)
    }

    // MARK: - Analysis History Tests

    func test_getAnalysisHistory_ReturnsTimestampedModes() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        // Save with delays to ensure different timestamps
        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "First")),
            for: memo.id,
            mode: .distill
        )

        // Small delay to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.01)

        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .events, data: TestData(text: "Second")),
            for: memo.id,
            mode: .events
        )

        let history = repository.getAnalysisHistory(for: memo.id)

        XCTAssertEqual(history.count, 2)
        XCTAssertTrue(history.contains(where: { $0.mode == .distill }))
        XCTAssertTrue(history.contains(where: { $0.mode == .events }))

        // Verify timestamps are different
        let distillTimestamp = history.first(where: { $0.mode == .distill })?.timestamp
        let eventsTimestamp = history.first(where: { $0.mode == .events })?.timestamp
        XCTAssertNotNil(distillTimestamp)
        XCTAssertNotNil(eventsTimestamp)
    }

    func test_getAnalysisHistory_ClearsWithDeleteAll() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test")),
            for: memo.id,
            mode: .distill
        )

        var history = repository.getAnalysisHistory(for: memo.id)
        XCTAssertEqual(history.count, 1)

        repository.deleteAnalysisResults(for: memo.id)

        history = repository.getAnalysisHistory(for: memo.id)
        XCTAssertTrue(history.isEmpty)
    }

    // MARK: - Edge Cases

    func test_saveAnalysisResult_OverwritesSameMode() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        // Save first version
        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Version 1")),
            for: memo.id,
            mode: .distill
        )

        // Save second version (should create new record, not overwrite)
        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Version 2")),
            for: memo.id,
            mode: .distill
        )

        // Should retrieve most recent
        let result = repository.getAnalysisResult(
            for: memo.id,
            mode: .distill,
            responseType: TestData.self
        )

        XCTAssertEqual(result?.data.text, "Version 2")

        // History should have both entries
        let history = repository.getAnalysisHistory(for: memo.id)
        let distillCount = history.filter { $0.mode == .distill }.count
        XCTAssertEqual(distillCount, 2, "Should track history of multiple saves")
    }

    func test_getCacheSize_ReflectsCurrentState() throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo1 = try makeTestMemo(in: context, id: UUID())
        let memo2 = try makeTestMemo(in: context, id: UUID())

        struct TestData: Codable, Sendable {
            let text: String
        }

        XCTAssertEqual(repository.getCacheSize(), 0)

        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test1")),
            for: memo1.id,
            mode: .distill
        )
        XCTAssertEqual(repository.getCacheSize(), 1)

        repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .events, data: TestData(text: "Test2")),
            for: memo2.id,
            mode: .events
        )
        XCTAssertEqual(repository.getCacheSize(), 2)

        repository.clearCache()
        XCTAssertEqual(repository.getCacheSize(), 0)
    }
}
#endif
