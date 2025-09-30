@testable import Sonora
import XCTest

@MainActor
final class SpotlightIndexerTests: XCTestCase {
    final class MockIndexer: SpotlightIndexing {
        var indexed: [UUID] = []
        var deleted: [UUID] = []
        func index(memoID: UUID) async { indexed.append(memoID) }
        func delete(memoID: UUID) async { deleted.append(memoID) }
        func reindexAll() async {}
    }

    func test_index_called_on_memoCreated_and_transcriptionCompleted() async {
        // Ensure Spotlight indexing is enabled for this test
        AppConfiguration.shared.searchIndexingEnabled = true
        let mock = MockIndexer()
        let bus = EventBus.shared
        let handler = SpotlightEventHandler(logger: Logger.shared, eventBus: bus, indexer: mock)
        _ = handler // retain

        let memo = Memo(filename: "UnitTest.m4a", fileURL: URL(fileURLWithPath: "/tmp/UnitTest.m4a"), creationDate: Date())
        await MainActor.run { bus.publish(.memoCreated(memo)) }
        await MainActor.run { bus.publish(.transcriptionCompleted(memoId: memo.id, text: "hello")) }

        // Allow handler to process
        let exp = expectation(description: "process")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        await fulfillment(of: [exp], timeout: 1.0)

        let didIndex = await MainActor.run { mock.indexed.contains(memo.id) }
        XCTAssertTrue(didIndex)
    }
}
