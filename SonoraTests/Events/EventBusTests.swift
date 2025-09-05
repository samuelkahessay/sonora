import XCTest
@testable import Sonora

@MainActor
final class EventBusTests: XCTestCase {

    override func tearDownWithError() throws {
        // Clean up any lingering subscriptions between tests
        EventBus.shared.removeAllSubscriptions()
    }

    // MARK: - Original Event Delivery Tests
    
    func testNavigateOpenMemoByIDEventDelivered() throws {
        let exp = expectation(description: "EventBus delivers navigateOpenMemoByID")

        let expectedId = UUID()
        var receivedId: UUID?

        // Subscribe
        let subId = EventBus.shared.subscribe(to: AppEvent.self, subscriber: nil) { event in
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
    
    // MARK: - Memory Management & Cleanup Tests
    
    func testWeakSubscriberCleanup() {
        let initialSubscriberCount = EventBus.shared.subscriberCount
        
        // Create a subscriber object that will be deallocated
        class TestSubscriber {
            var receivedEvents: [AppEvent] = []
            
            func handleEvent(_ event: AppEvent) {
                receivedEvents.append(event)
            }
        }
        
        weak var weakSubscriber: TestSubscriber?
        var subscriptionId: UUID?
        
        autoreleasepool {
            let subscriber = TestSubscriber()
            weakSubscriber = subscriber
            
            // Subscribe with weak reference tracking
            subscriptionId = EventBus.shared.subscribe(
                to: AppEvent.self,
                subscriber: subscriber
            ) { event in
                subscriber.handleEvent(event)
            }
            
            XCTAssertNotNil(weakSubscriber, "Subscriber should be alive inside autoreleasepool")
            XCTAssertEqual(EventBus.shared.subscriberCount, initialSubscriberCount + 1)
        }
        
        // Allow cleanup to occur
        let cleanupExpectation = expectation(description: "Weak subscriber cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 1.0)
        
        XCTAssertNil(weakSubscriber, "Subscriber should be deallocated")
        
        // Publish an event to trigger cleanup
        EventBus.shared.publish(.navigateOpenMemoByID(memoId: UUID()))
        
        // Verify cleanup occurred
        XCTAssertLessThanOrEqual(EventBus.shared.subscriberCount, initialSubscriberCount, "Dead subscriptions should be cleaned up")
        
        print("✅ Weak subscriber cleanup: Dead subscriptions removed automatically")
    }
    
    func testAutomaticCleanupOnPublish() {
        let initialCount = EventBus.shared.subscriberCount
        var subscriptionIds: [UUID] = []
        
        // Create multiple subscribers that will become dead
        for _ in 0..<10 {
            autoreleasepool {
                class TempSubscriber {}
                let subscriber = TempSubscriber()
                
                let subId = EventBus.shared.subscribe(
                    to: AppEvent.self,
                    subscriber: subscriber
                ) { _ in
                    // Handler
                }
                subscriptionIds.append(subId)
            }
        }
        
        let countAfterSubscriptions = EventBus.shared.subscriberCount
        XCTAssertGreaterThan(countAfterSubscriptions, initialCount, "Subscriptions should be added")
        
        // Allow objects to be deallocated
        let deallocExpectation = expectation(description: "Object deallocation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            deallocExpectation.fulfill()
        }
        wait(for: [deallocExpectation], timeout: 1.0)
        
        // Publish event to trigger cleanup
        EventBus.shared.publish(.navigateOpenMemoByID(memoId: UUID()))
        
        // Cleanup should have occurred
        let finalCount = EventBus.shared.subscriberCount
        XCTAssertLessThan(finalCount, countAfterSubscriptions, "Dead subscriptions should be cleaned up on publish")
        
        print("✅ Automatic cleanup: \(countAfterSubscriptions - finalCount) dead subscriptions cleaned up")
    }
    
    func testScheduledCleanupTriggers() {
        let initialCount = EventBus.shared.subscriberCount
        
        // Add many subscriptions to trigger cleanup threshold
        var activeSubscriptions: [UUID] = []
        
        for i in 0..<150 { // Exceed maxSubscriptionsBeforeCleanup (100)
            let subId = EventBus.shared.subscribe(to: AppEvent.self, subscriber: nil) { _ in
                // Active handler
            }
            activeSubscriptions.append(subId)
        }
        
        let countAfterManySubscriptions = EventBus.shared.subscriberCount
        
        // Publish event to potentially trigger threshold-based cleanup
        EventBus.shared.publish(.navigateOpenMemoByID(memoId: UUID()))
        
        // Since all subscriptions are valid, count should remain high
        XCTAssertEqual(EventBus.shared.subscriberCount, countAfterManySubscriptions, "Valid subscriptions should not be cleaned up")
        
        // Clean up test subscriptions
        for subId in activeSubscriptions {
            EventBus.shared.unsubscribe(subId)
        }
        
        print("✅ Scheduled cleanup: Threshold-based cleanup respects valid subscriptions")
    }
    
    func testSubscriptionValidityTracking() {
        class TestSubscriber {
            var isActive = true
        }
        
        let subscriber = TestSubscriber()
        
        let subscriptionId = EventBus.shared.subscribe(
            to: AppEvent.self,
            subscriber: subscriber
        ) { _ in
            // Handler
        }
        
        let initialCount = EventBus.shared.subscriberCount
        
        // Publish event - subscription should work
        var eventReceived = false
        let workingSubId = EventBus.shared.subscribe(to: AppEvent.self, subscriber: nil) { _ in
            eventReceived = true
        }
        
        EventBus.shared.publish(.navigateOpenMemoByID(memoId: UUID()))
        
        XCTAssertTrue(eventReceived, "Valid subscriptions should receive events")
        
        // Clean up
        EventBus.shared.unsubscribe(subscriptionId)
        EventBus.shared.unsubscribe(workingSubId)
        
        print("✅ Subscription validity: Active subscriptions properly tracked and functional")
    }
    
    func testMemoryLeakPrevention() {
        let initialMemory = getMemoryUsage()
        let initialSubscriberCount = EventBus.shared.subscriberCount
        
        // Create many subscriptions that will become dead
        for cycle in 0..<20 {
            autoreleasepool {
                for i in 0..<50 {
                    class TempSubscriber {
                        let id = UUID()
                    }
                    let subscriber = TempSubscriber()
                    
                    _ = EventBus.shared.subscribe(
                        to: AppEvent.self,
                        subscriber: subscriber
                    ) { event in
                        // Handler that captures subscriber
                        _ = subscriber.id
                    }
                }
            }
            
            // Periodically trigger cleanup
            if cycle % 5 == 0 {
                EventBus.shared.publish(.navigateOpenMemoByID(memoId: UUID()))
            }
        }
        
        // Allow cleanup to occur
        let cleanupExpectation = expectation(description: "Memory leak prevention cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 1.0)
        
        // Final cleanup trigger
        EventBus.shared.publish(.navigateOpenMemoByID(memoId: UUID()))
        
        let finalMemory = getMemoryUsage()
        let finalSubscriberCount = EventBus.shared.subscriberCount
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be minimal
        XCTAssertLessThan(memoryIncrease, 10.0, "Memory increase should be under 10MB after 1000 dead subscriptions")
        
        // Subscriber count should not grow indefinitely
        let subscriberIncrease = finalSubscriberCount - initialSubscriberCount
        XCTAssertLessThan(subscriberIncrease, 100, "Subscriber count should not grow indefinitely")
        
        print("✅ Memory leak prevention: \(String(format: "%.2f", memoryIncrease))MB increase, \(subscriberIncrease) net subscriber increase after 1000 dead subscriptions")
    }
    
    func testCleanupInterval() {
        let initialCount = EventBus.shared.subscriberCount
        
        // Create some dead subscriptions
        autoreleasepool {
            for _ in 0..<20 {
                class TempSubscriber {}
                let subscriber = TempSubscriber()
                
                _ = EventBus.shared.subscribe(
                    to: AppEvent.self,
                    subscriber: subscriber
                ) { _ in
                    // Handler
                }
            }
        }
        
        let countWithDeadSubscriptions = EventBus.shared.subscriberCount
        
        // Publish multiple events to trigger cleanup
        for _ in 0..<5 {
            EventBus.shared.publish(.navigateOpenMemoByID(memoId: UUID()))
        }
        
        let finalCount = EventBus.shared.subscriberCount
        let cleanedUp = countWithDeadSubscriptions - finalCount
        
        XCTAssertGreaterThan(cleanedUp, 0, "Some dead subscriptions should be cleaned up")
        
        print("✅ Cleanup interval: \(cleanedUp) subscriptions cleaned up through interval mechanism")
    }
    
    func testSubscriptionManagerAutomaticCleanup() {
        let manager = EventSubscriptionManager()
        let initialCount = EventBus.shared.subscriberCount
        
        // Add managed subscriptions
        for _ in 0..<10 {
            manager.subscribe(to: AppEvent.self) { _ in
                // Handler
            }
        }
        
        let countWithManagedSubscriptions = EventBus.shared.subscriberCount
        XCTAssertGreaterThan(countWithManagedSubscriptions, initialCount, "Managed subscriptions should be added")
        
        // Cleanup manager
        manager.cleanup()
        
        let countAfterCleanup = EventBus.shared.subscriberCount
        XCTAssertLessThanOrEqual(countAfterCleanup, initialCount, "Managed subscriptions should be cleaned up")
        
        print("✅ Subscription manager: Automatic cleanup removed \(countWithManagedSubscriptions - countAfterCleanup) managed subscriptions")
    }
    
    // MARK: - Performance Tests
    
    func testCleanupPerformance() {
        // Create many subscriptions (some dead, some alive)
        var liveSubscriptions: [Any] = []
        
        // Add live subscriptions
        for _ in 0..<50 {
            class LiveSubscriber {}
            let subscriber = LiveSubscriber()
            liveSubscriptions.append(subscriber)
            
            _ = EventBus.shared.subscribe(
                to: AppEvent.self,
                subscriber: subscriber
            ) { _ in
                // Handler
            }
        }
        
        // Add dead subscriptions
        autoreleasepool {
            for _ in 0..<50 {
                class DeadSubscriber {}
                let subscriber = DeadSubscriber()
                
                _ = EventBus.shared.subscribe(
                    to: AppEvent.self,
                    subscriber: subscriber
                ) { _ in
                    // Handler
                }
            }
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Trigger cleanup
        EventBus.shared.publish(.navigateOpenMemoByID(memoId: UUID()))
        
        let cleanupTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        XCTAssertLessThan(cleanupTime, 50.0, "Cleanup should complete within 50ms")
        
        print("✅ Cleanup performance: \(String(format: "%.2f", cleanupTime))ms for mixed live/dead subscriptions")
        
        // Clear live subscriptions
        liveSubscriptions.removeAll()
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0.0
        }
    }
}

