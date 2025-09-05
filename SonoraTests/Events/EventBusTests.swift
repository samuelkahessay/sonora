import XCTest
@testable import Sonora

final class EventBusTests: XCTestCase {

    override func tearDownWithError() throws {
        // Clean up any lingering subscriptions between tests
        EventBus.shared.removeAllSubscriptions()
    }

    @MainActor
    func testNavigateOpenMemoByIDEventDelivered() throws {
        let exp = expectation(description: "EventBus delivers navigateOpenMemoByID")

        let expectedId = UUID()
        var receivedId: UUID?

        // Subscribe
        let subId = EventBus.shared.subscribe(to: AppEvent.self) { event in
            switch event {
            case .navigateOpenMemoByID(let memoId):
                receivedId = memoId
                exp.fulfill()
            default:
                break
            }
        }

        // Publish
        EventBus.shared.publish(.navigateOpenMemoByID(memoId: expectedId))

        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(receivedId, expectedId)

        // Unsubscribe
        EventBus.shared.unsubscribe(subId)
    }
}

