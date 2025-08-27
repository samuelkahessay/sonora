import Foundation
import SwiftUI

/// Helper for testing and debugging event flow
/// Provides methods to simulate events and verify handler responses
@MainActor
public final class EventFlowTestHelper: ObservableObject {
    
    // MARK: - Dependencies
    private let eventBus: EventBusProtocol
    private let logger: LoggerProtocol
    private let registry: EventHandlerRegistry
    
    // MARK: - Test State
    @Published public var testResults: [String] = []
    @Published public var isTestInProgress: Bool = false
    
    // MARK: - Initialization
    public init(
        eventBus: EventBusProtocol = EventBus.shared,
        logger: LoggerProtocol = Logger.shared,
        registry: EventHandlerRegistry = .shared
    ) {
        self.eventBus = eventBus
        self.logger = logger
        self.registry = registry
    }
    
    // MARK: - Test Methods
    
    /// Run comprehensive event flow test
    public func runEventFlowTest() async {
        isTestInProgress = true
        testResults.removeAll()
        
        addTestResult("🧪 Starting comprehensive event flow test...")
        
        // Test 1: Registry status
        await testRegistryStatus()
        
        // Test 2: Memo creation event
        await testMemoCreationEvent()
        
        // Test 3: Transcription completion event
        await testTranscriptionEvent()
        
        // Test 4: Analysis completion events
        await testAnalysisEvents()
        
        // Test 5: Handler statistics
        await testHandlerStatistics()
        
        addTestResult("✅ Event flow test completed")
        isTestInProgress = false
    }
    
    private func testRegistryStatus() async {
        addTestResult("\n📊 Testing EventHandlerRegistry status...")
        
        let status = registry.detailedStatus
        addTestResult("Registry status:\n\(status)")
        
        let activeHandlers = registry.activeHandlerNames
        addTestResult("Active handlers: \(activeHandlers.joined(separator: ", "))")
        
        if activeHandlers.contains("MemoEventHandler") {
            addTestResult("✅ MemoEventHandler is active")
        } else {
            addTestResult("❌ MemoEventHandler is NOT active")
        }
    }
    
    private func testMemoCreationEvent() async {
        addTestResult("\n📝 Testing memo creation event...")
        
        let testMemo = DomainMemo(
            filename: "Test Recording - \(Date().formatted(.dateTime))",
            fileURL: URL(fileURLWithPath: "/tmp/test_memo.m4a"),
            creationDate: Date()
        )
        
        addTestResult("Publishing memoCreated event for: \(testMemo.filename)")
        
        // Subscribe to verify event was received
        var eventReceived = false
        let subscriptionId = eventBus.subscribe(to: AppEvent.self) { event in
            if case .memoCreated(let memo) = event, memo.id == testMemo.id {
                eventReceived = true
            }
        }
        
        // Publish the event
        eventBus.publish(.memoCreated(testMemo))
        
        // Give time for processing
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        if eventReceived {
            addTestResult("✅ MemoCreated event was received by subscriber")
        } else {
            addTestResult("❌ MemoCreated event was NOT received")
        }
        
        eventBus.unsubscribe(subscriptionId)
    }
    
    private func testTranscriptionEvent() async {
        addTestResult("\n📝 Testing transcription completion event...")
        
        let testMemoId = UUID()
        let testTranscription = "This is a test transcription for event flow verification."
        
        addTestResult("Publishing transcriptionCompleted event for memo: \(testMemoId)")
        
        // Subscribe to verify event
        var eventReceived = false
        let subscriptionId = eventBus.subscribe(to: AppEvent.self) { event in
            if case .transcriptionCompleted(let memoId, _) = event, memoId == testMemoId {
                eventReceived = true
            }
        }
        
        // Publish the event
        eventBus.publish(.transcriptionCompleted(memoId: testMemoId, text: testTranscription))
        
        // Give time for processing
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        if eventReceived {
            addTestResult("✅ TranscriptionCompleted event was received")
        } else {
            addTestResult("❌ TranscriptionCompleted event was NOT received")
        }
        
        eventBus.unsubscribe(subscriptionId)
    }
    
    private func testAnalysisEvents() async {
        addTestResult("\n📊 Testing analysis completion events...")
        
        let testMemoId = UUID()
        let analysisTypes: [AnalysisMode] = [.tldr, .themes, .todos, .analysis]
        
        for analysisType in analysisTypes {
            addTestResult("Testing \(analysisType.displayName) analysis event...")
            
            let testResult = "Test \(analysisType.displayName) result"
            
            // Subscribe to verify event
            var eventReceived = false
            let subscriptionId = eventBus.subscribe(to: AppEvent.self) { event in
                if case .analysisCompleted(let memoId, let type, _) = event, 
                   memoId == testMemoId && type == analysisType {
                    eventReceived = true
                }
            }
            
            // Publish the event
            eventBus.publish(.analysisCompleted(memoId: testMemoId, type: analysisType, result: testResult))
            
            // Give time for processing
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            
            if eventReceived {
                addTestResult("  ✅ \(analysisType.displayName) event received")
            } else {
                addTestResult("  ❌ \(analysisType.displayName) event NOT received")
            }
            
            eventBus.unsubscribe(subscriptionId)
        }
    }
    
    private func testHandlerStatistics() async {
        addTestResult("\n📈 Testing handler statistics...")
        
        let handlerNames = registry.registeredHandlerNames
        
        for handlerName in handlerNames {
            if let stats = registry.getHandlerStatistics(handlerName) {
                addTestResult("\(handlerName) statistics:")
                addTestResult(stats)
            } else {
                addTestResult("No statistics available for \(handlerName)")
            }
            addTestResult("") // Empty line for readability
        }
    }
    
    // MARK: - Individual Event Tests
    
    /// Test recording events
    public func testRecordingEvents() {
        addTestResult("\n🎙️ Testing recording events...")
        
        let testMemoId = UUID()
        
        // Test recording started
        eventBus.publish(.recordingStarted(memoId: testMemoId))
        addTestResult("Published recordingStarted event")
        
        // Test recording completed (after short delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.eventBus.publish(.recordingCompleted(memoId: testMemoId))
            self.addTestResult("Published recordingCompleted event")
        }
    }
    
    /// Get current EventBus statistics
    public func getEventBusStatistics() -> String {
        return eventBus.subscriptionStats
    }
    
    // MARK: - Helper Methods
    
    private func addTestResult(_ result: String) {
        testResults.append(result)
        logger.debug("EventFlowTest: \(result)", 
                    category: .system, 
                    context: LogContext())
    }
    
    /// Clear test results
    public func clearTestResults() {
        testResults.removeAll()
    }
    
    /// Export test results for debugging
    public func exportTestResults() -> String {
        let header = """
        Event Flow Test Results
        Generated: \(Date().formatted(.dateTime))
        
        """
        
        return header + testResults.joined(separator: "\n")
    }
}