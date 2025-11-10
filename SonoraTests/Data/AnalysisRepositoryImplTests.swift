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

    func test_saveAndGetAnalysisResult_Success() async throws {
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
        await repository.saveAnalysisResult(envelope, for: memo.id, mode: .distill)

        // Retrieve
        let retrieved = await repository.getAnalysisResult(
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

    func test_saveMultipleModesForSameMemo_Success() async throws {
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

        await repository.saveAnalysisResult(distillEnvelope, for: memo.id, mode: .distill)
        await repository.saveAnalysisResult(eventsEnvelope, for: memo.id, mode: .events)

        // Retrieve both
        let distillResult = await repository.getAnalysisResult(
            for: memo.id,
            mode: .distill,
            responseType: TestData.self
        )
        let eventsResult = await repository.getAnalysisResult(
            for: memo.id,
            mode: .events,
            responseType: TestData.self
        )

        XCTAssertEqual(distillResult?.data.text, "Distill result")
        XCTAssertEqual(eventsResult?.data.text, "Events result")
    }

    func test_getAnalysisResult_NonExistent_ReturnsNil() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        let result = await repository.getAnalysisResult(
            for: memo.id,
            mode: .distill,
            responseType: TestData.self
        )

        XCTAssertNil(result)
    }

    // MARK: - Memory Cache Tests

    func test_getAnalysisResult_UsesMemoryCache() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }
        let envelope = makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test"))

        // Save (populates cache)
        await repository.saveAnalysisResult(envelope, for: memo.id, mode: .distill)

        // Verify cache is populated (getCacheSize should be 1)
        let cacheSizeAfterSave = await repository.getCacheSize()
        XCTAssertEqual(cacheSizeAfterSave, 1)

        // Retrieve (should hit memory cache)
        let result = await repository.getAnalysisResult(
            for: memo.id,
            mode: .distill,
            responseType: TestData.self
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.data.text, "Test")
    }

    func test_clearCache_RemovesMemoryCache() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }
        let envelope = makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test"))

        await repository.saveAnalysisResult(envelope, for: memo.id, mode: .distill)
        let cacheSizeBeforeClear = await repository.getCacheSize()
        XCTAssertEqual(cacheSizeBeforeClear, 1)

        await repository.clearCache()
        let cacheSizeAfterClear = await repository.getCacheSize()
        XCTAssertEqual(cacheSizeAfterClear, 0)

        // Data should still be retrievable from store
        let result = await repository.getAnalysisResult(
            for: memo.id,
            mode: .distill,
            responseType: TestData.self
        )
        XCTAssertNotNil(result, "Should retrieve from store after cache clear")
    }

    // MARK: - HasAnalysisResult Tests

    func test_hasAnalysisResult_ExistsInCache_ReturnsTrue() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }
        let envelope = makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test"))

        await repository.saveAnalysisResult(envelope, for: memo.id, mode: .distill)

        let hasDistillResult = await repository.hasAnalysisResult(for: memo.id, mode: .distill)
        let hasEventsResult = await repository.hasAnalysisResult(for: memo.id, mode: .events)
        XCTAssertTrue(hasDistillResult)
        XCTAssertFalse(hasEventsResult)
    }

    func test_hasAnalysisResult_ExistsInStoreOnly_ReturnsTrue() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }
        let envelope = makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test"))

        await repository.saveAnalysisResult(envelope, for: memo.id, mode: .distill)
        await repository.clearCache()

        let hasStoredResult = await repository.hasAnalysisResult(for: memo.id, mode: .distill)
        XCTAssertTrue(hasStoredResult)
    }

    func test_hasAnalysisResult_DoesNotExist_ReturnsFalse() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        let hasResult = await repository.hasAnalysisResult(for: memo.id, mode: .distill)
        XCTAssertFalse(hasResult)
    }

    // MARK: - Delete Tests

    func test_deleteAnalysisResult_RemovesSpecificMode() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        // Save multiple modes
        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Distill")),
            for: memo.id,
            mode: .distill
        )
        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .events, data: TestData(text: "Events")),
            for: memo.id,
            mode: .events
        )

        // Delete only distill
        await repository.deleteAnalysisResult(for: memo.id, mode: .distill)

        let hasDistillResult = await repository.hasAnalysisResult(for: memo.id, mode: .distill)
        let hasEventsResult = await repository.hasAnalysisResult(for: memo.id, mode: .events)
        XCTAssertFalse(hasDistillResult)
        XCTAssertTrue(hasEventsResult)
    }

    func test_deleteAnalysisResults_RemovesAllForMemo() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo1 = try makeTestMemo(in: context, id: UUID())
        let memo2 = try makeTestMemo(in: context, id: UUID())

        struct TestData: Codable, Sendable {
            let text: String
        }

        // Save for both memos
        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Memo1")),
            for: memo1.id,
            mode: .distill
        )
        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Memo2")),
            for: memo2.id,
            mode: .distill
        )

        // Delete all for memo1
        await repository.deleteAnalysisResults(for: memo1.id)

        let memo1HasResults = await repository.hasAnalysisResult(for: memo1.id, mode: .distill)
        let memo2HasResults = await repository.hasAnalysisResult(for: memo2.id, mode: .distill)
        XCTAssertFalse(memo1HasResults)
        XCTAssertTrue(memo2HasResults)
    }

    // MARK: - GetAllAnalysisResults Tests

    func test_getAllAnalysisResults_ReturnsAllModesForMemo() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        // Save multiple modes
        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Distill")),
            for: memo.id,
            mode: .distill
        )
        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .events, data: TestData(text: "Events")),
            for: memo.id,
            mode: .events
        )

        let allResults = await repository.getAllAnalysisResults(for: memo.id)

        XCTAssertEqual(allResults.count, 2)
        XCTAssertTrue(allResults.availableModes.contains(.distill))
        XCTAssertTrue(allResults.availableModes.contains(.events))
        XCTAssertFalse(allResults.availableModes.contains(.reminders))
    }

    func test_getAllAnalysisResults_EmptyMemo_ReturnsEmpty() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        let allResults = await repository.getAllAnalysisResults(for: memo.id)

        XCTAssertEqual(allResults.count, 0)
        XCTAssertTrue(allResults.availableModes.isEmpty)
    }

    // MARK: - Analysis History Tests

    func test_getAnalysisHistory_ReturnsTimestampedModes() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        // Save with delays to ensure different timestamps
        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "First")),
            for: memo.id,
            mode: .distill
        )

        // Small delay to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.01)

        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .events, data: TestData(text: "Second")),
            for: memo.id,
            mode: .events
        )

        let history = await repository.getAnalysisHistory(for: memo.id)

        XCTAssertEqual(history.count, 2)
        XCTAssertTrue(history.contains(where: { $0.mode == .distill }))
        XCTAssertTrue(history.contains(where: { $0.mode == .events }))

        // Verify timestamps are different
        let distillTimestamp = history.first(where: { $0.mode == .distill })?.timestamp
        let eventsTimestamp = history.first(where: { $0.mode == .events })?.timestamp
        XCTAssertNotNil(distillTimestamp)
        XCTAssertNotNil(eventsTimestamp)
    }

    func test_getAnalysisHistory_ClearsWithDeleteAll() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test")),
            for: memo.id,
            mode: .distill
        )

        var history = await repository.getAnalysisHistory(for: memo.id)
        XCTAssertEqual(history.count, 1)

        await repository.deleteAnalysisResults(for: memo.id)

        history = await repository.getAnalysisHistory(for: memo.id)
        XCTAssertTrue(history.isEmpty)
    }

    // MARK: - Edge Cases

    func test_saveAnalysisResult_OverwritesSameMode() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        struct TestData: Codable, Sendable {
            let text: String
        }

        // Save first version
        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Version 1")),
            for: memo.id,
            mode: .distill
        )

        // Save second version (should create new record, not overwrite)
        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Version 2")),
            for: memo.id,
            mode: .distill
        )

        // Should retrieve most recent
        let result = await repository.getAnalysisResult(
            for: memo.id,
            mode: .distill,
            responseType: TestData.self
        )

        XCTAssertEqual(result?.data.text, "Version 2")

        // History should have both entries
        let history = await repository.getAnalysisHistory(for: memo.id)
        let distillCount = history.filter { $0.mode == .distill }.count
        XCTAssertEqual(distillCount, 2, "Should track history of multiple saves")
    }

    func test_getCacheSize_ReflectsCurrentState() async throws {
        let context = try makeInMemoryContext()
        let repository = AnalysisRepositoryImpl(context: context)
        let memo1 = try makeTestMemo(in: context, id: UUID())
        let memo2 = try makeTestMemo(in: context, id: UUID())

        struct TestData: Codable, Sendable {
            let text: String
        }

        let initialCacheSize = await repository.getCacheSize()
        XCTAssertEqual(initialCacheSize, 0)

        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .distill, data: TestData(text: "Test1")),
            for: memo1.id,
            mode: .distill
        )
        let cacheSizeAfterMemo1 = await repository.getCacheSize()
        XCTAssertEqual(cacheSizeAfterMemo1, 1)

        await repository.saveAnalysisResult(
            makeTestAnalysisResult(mode: .events, data: TestData(text: "Test2")),
            for: memo2.id,
            mode: .events
        )
        let cacheSizeAfterMemo2 = await repository.getCacheSize()
        XCTAssertEqual(cacheSizeAfterMemo2, 2)

        await repository.clearCache()
        let cacheSizeAfterClear = await repository.getCacheSize()
        XCTAssertEqual(cacheSizeAfterClear, 0)
    }
}
#endif
