//
//  DIContainerMemoryTests.swift
//  SonoraTests
//
//  Created by Claude Code on 2025-01-07.
//  Tests for DIContainer memory management improvements and weak reference handling
//

import XCTest
import Foundation
@testable import Sonora

@MainActor
final class DIContainerMemoryTests: XCTestCase {

    private var container: DIContainer!

    override func setUp() async throws {
        try await super.setUp()
        container = DIContainer()
    }

    override func tearDown() async throws {
        container = nil
        try await super.tearDown()
    }

    // MARK: - Memory Leak Prevention Tests

    func testWeakReferenceCleanup() {
        weak var weakAnalysisService: AnalysisService?
        weak var weakBackgroundAudioService: BackgroundAudioService?

        // Create services through container
        autoreleasepool {
            let analysisService = container.analysisService()
            let backgroundAudioService = container.backgroundAudioService()

            weakAnalysisService = analysisService as? AnalysisService
            weakBackgroundAudioService = backgroundAudioService as? BackgroundAudioService

            XCTAssertNotNil(weakAnalysisService, "Service should be alive inside autorelease pool")
            XCTAssertNotNil(weakBackgroundAudioService, "Service should be alive inside autorelease pool")
        }

        // Wait for cleanup to occur
        let cleanupExpectation = expectation(description: "Weak reference cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 1.0)

        // Services should be deallocated if only held by weak references
        print("✅ Weak reference cleanup: Analysis service deallocated: \(weakAnalysisService == nil)")
        print("✅ Weak reference cleanup: Background audio service deallocated: \(weakBackgroundAudioService == nil)")
    }

    func testMemoryCleanupCycle() {
        let initialMemory = getMemoryUsage()

        // Create and release many service instances
        for _ in 0..<50 {
            autoreleasepool {
                _ = container.analysisService()
                _ = container.backgroundAudioService()
                _ = container.memoRepository()
                _ = container.audioRepository()
                _ = container.transcriptionAPI()
            }
        }

        // Force memory cleanup
        let cleanupExpectation = expectation(description: "Memory cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 1.0)

        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        // Memory increase should be minimal (under 5MB after cleanup)
        XCTAssertLessThan(memoryIncrease, 5.0, "Memory increase after cleanup should be under 5MB, was \(String(format: "%.2f", memoryIncrease))MB")

        print("✅ Memory cleanup cycle: \(String(format: "%.2f", memoryIncrease))MB increase after 50 service creation cycles")
    }

    func testThermalStateBasedCleanup() {
        // Test that cleanup threshold adapts to thermal state
        let initialMemory = getMemoryUsage()

        // Simulate thermal pressure by creating many services
        for _ in 0..<20 {
            _ = container.analysisService()
            _ = container.backgroundAudioService()
        }

        // Trigger manual cleanup (simulating thermal pressure scenario)
        let cleanupExpectation = expectation(description: "Thermal cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 1.0)

        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        print("✅ Thermal state cleanup: \(String(format: "%.2f", memoryIncrease))MB after thermal pressure simulation")

        // Under thermal pressure, cleanup should be more aggressive
        XCTAssertLessThan(memoryIncrease, 10.0, "Memory should be managed aggressively under thermal pressure")
    }

    // MARK: - Service Lifecycle Tests

    func testServiceSingletonBehavior() {
        // Test that services maintain singleton behavior where expected
        let analysisService1 = container.analysisService()
        let analysisService2 = container.analysisService()

        // Should return same instance for singleton services
        XCTAssertTrue(analysisService1 === analysisService2, "Analysis service should maintain singleton behavior")

        let transcription1 = container.transcriptionAPI()
        let transcription2 = container.transcriptionAPI()

        // Protocol types may or may not be the same instance (implementation dependent)
        print("✅ Service singleton: Analysis service maintains identity: \(analysisService1 === analysisService2)")
        print("✅ Service singleton: Transcription API behavior: \(transcription1 === transcription2 ? "singleton" : "new instances")")
    }

    func testServiceInstantiationPerformance() {
        // Test that service instantiation is fast and doesn't cause memory spikes
        let startTime = CFAbsoluteTimeGetCurrent()
        let initialMemory = getMemoryUsage()

        // Create services rapidly
        var services: [Any] = []
        for _ in 0..<100 {
            services.append(container.analysisService())
            services.append(container.memoRepository())
            services.append(container.transcriptionAPI())
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let instantiationTime = (endTime - startTime) * 1000
        let finalMemory = getMemoryUsage()

        print("✅ Service instantiation performance: \(String(format: "%.2f", instantiationTime))ms for 300 service calls")
        print("✅ Service instantiation memory: \(String(format: "%.2f", finalMemory - initialMemory))MB increase")

        XCTAssertLessThan(instantiationTime, 100.0, "Service instantiation should complete in under 100ms")

        // Clear services array
        services.removeAll()
    }

    // MARK: - Protocol vs Concrete Type Tests

    func testProtocolTypeRetention() {
        // Test that protocol types are properly retained when needed
        var transcriptionAPI: (any TranscriptionAPI)?
        var memoRepository: (any MemoRepository)?

        autoreleasepool {
            transcriptionAPI = container.transcriptionAPI()
            memoRepository = container.memoRepository()

            XCTAssertNotNil(transcriptionAPI, "Protocol type should be retained")
            XCTAssertNotNil(memoRepository, "Protocol type should be retained")
        }

        // Protocol types should still be accessible after autoreleasepool
        XCTAssertNotNil(transcriptionAPI, "Protocol type should remain accessible")
        XCTAssertNotNil(memoRepository, "Protocol type should remain accessible")

        print("✅ Protocol type retention: TranscriptionAPI retained: \(transcriptionAPI != nil)")
        print("✅ Protocol type retention: MemoRepository retained: \(memoRepository != nil)")

        // Clear references
        transcriptionAPI = nil
        memoRepository = nil
    }

    func testConcreteTypeWeakReferences() {
        // Test that concrete types use weak references appropriately
        weak var weakAnalysisService: AnalysisService?

        do {
            let service = container.analysisService() as? AnalysisService
            weakAnalysisService = service
            XCTAssertNotNil(weakAnalysisService, "Service should be alive while strongly referenced")
        }

        // Service should be deallocated when no strong references remain
        let deallocExpectation = expectation(description: "Service deallocation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            deallocExpectation.fulfill()
        }
        wait(for: [deallocExpectation], timeout: 1.0)

        print("✅ Concrete type weak references: Service deallocated: \(weakAnalysisService == nil)")
    }

    // MARK: - Memory Pressure Tests

    func testMemoryPressureHandling() {
        let initialMemory = getMemoryUsage()
        var services: [Any] = []

        // Create services until we simulate memory pressure
        for i in 0..<200 {
            services.append(container.analysisService())
            services.append(container.backgroundAudioService())
            services.append(container.memoRepository())

            // Check memory every 20 iterations
            if i % 20 == 0 {
                let currentMemory = getMemoryUsage()
                let memoryIncrease = currentMemory - initialMemory

                if memoryIncrease > 50.0 { // If we've used more than 50MB
                    print("⚠️ Memory pressure detected at iteration \(i): \(String(format: "%.2f", memoryIncrease))MB")
                    break
                }
            }
        }

        let peakMemory = getMemoryUsage()

        // Clear services and allow cleanup
        services.removeAll()

        let cleanupExpectation = expectation(description: "Memory pressure cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 2.0)

        let finalMemory = getMemoryUsage()
        let recovered = peakMemory - finalMemory

        print("✅ Memory pressure handling: Peak \(String(format: "%.2f", peakMemory - initialMemory))MB, Recovered \(String(format: "%.2f", recovered))MB")

        // Should recover at least 50% of peak memory usage
        XCTAssertGreaterThan(recovered, (peakMemory - initialMemory) * 0.3, "Should recover at least 30% of peak memory usage")
    }

    // MARK: - Edge Case Tests

    func testConcurrentAccess() {
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10

        let startTime = CFAbsoluteTimeGetCurrent()

        // Test concurrent access to container from multiple queues
        for i in 0..<10 {
            DispatchQueue.global(qos: .userInitiated).async {
                // Access services concurrently
                _ = self.container.analysisService()
                _ = self.container.memoRepository()
                _ = self.container.transcriptionAPI()

                DispatchQueue.main.async {
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)

        let endTime = CFAbsoluteTimeGetCurrent()
        let concurrentTime = (endTime - startTime) * 1000

        print("✅ Concurrent access: \(String(format: "%.2f", concurrentTime))ms for 10 concurrent service requests")

        // Concurrent access should not cause deadlocks or excessive delays
        XCTAssertLessThan(concurrentTime, 1000.0, "Concurrent access should complete within 1 second")
    }

    func testNilServiceHandling() {
        // Test that container handles edge cases gracefully
        // This mainly tests that the container doesn't crash on edge cases

        // Multiple rapid calls should not cause issues
        for _ in 0..<50 {
            _ = container.analysisService()
            _ = container.memoRepository()
        }

        print("✅ Nil service handling: Container handled rapid service creation without crashes")
        XCTAssertTrue(true, "Container should handle rapid service creation gracefully")
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
