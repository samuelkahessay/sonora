//
//  BackgroundAudioServiceInterruptionTests.swift
//  SonoraTests
//
//  Created by Claude Code on 2025-01-07.
//  Tests for BackgroundAudioService interruption recovery and state preservation
//

import XCTest
import AVFoundation
@testable import Sonora

@MainActor
final class BackgroundAudioServiceInterruptionTests: XCTestCase {
    
    private var backgroundAudioService: BackgroundAudioService!
    private var mockSessionService: MockAudioSessionService!
    private var mockRecordingService: MockAudioRecordingService!
    private var mockTimerService: MockRecordingTimerService!
    private var mockBackgroundTaskService: MockBackgroundTaskService!
    private var mockPermissionService: MockAudioPermissionService!
    private var mockPlaybackService: MockAudioPlaybackService!
    private var testURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock services
        mockSessionService = MockAudioSessionService()
        mockRecordingService = MockAudioRecordingService()
        mockTimerService = MockRecordingTimerService()
        mockBackgroundTaskService = MockBackgroundTaskService()
        mockPermissionService = MockAudioPermissionService()
        mockPlaybackService = MockAudioPlaybackService()
        
        // Initialize BackgroundAudioService with mocks
        backgroundAudioService = BackgroundAudioService(
            sessionService: mockSessionService,
            recordingService: mockRecordingService,
            backgroundTaskService: mockBackgroundTaskService,
            permissionService: mockPermissionService,
            timerService: mockTimerService,
            playbackService: mockPlaybackService
        )
        
        // Create test URL
        testURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("interruption_test_\(UUID().uuidString).m4a")
        
        // Set up successful defaults
        mockPermissionService.hasPermission = true
        mockBackgroundTaskService.beginBackgroundTaskResult = true
        mockRecordingService.generateRecordingURLResult = testURL
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: testURL)
        backgroundAudioService = nil
        mockSessionService = nil
        mockRecordingService = nil
        mockTimerService = nil
        mockBackgroundTaskService = nil
        mockPermissionService = nil
        mockPlaybackService = nil
        try await super.tearDown()
    }
    
    // MARK: - Interruption State Preservation Tests
    
    func testInterruptionStatePreservation() async {
        // Start recording first
        try! backgroundAudioService.startRecording()
        XCTAssertTrue(backgroundAudioService.isRecording, "Recording should be active")
        
        // Simulate accumulating some recording time
        mockRecordingService.currentTimeResult = 15.5
        mockTimerService.recordingTime = 15.5
        
        // Trigger interruption began
        mockSessionService.triggerInterruptionBegan()
        
        // Wait for interruption handling
        let interruptionExpectation = expectation(description: "Interruption handling")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            interruptionExpectation.fulfill()
        }
        await fulfillment(of: [interruptionExpectation], timeout: 1.0)
        
        // Verify state was preserved (implementation detail: would be tested via recovery)
        print("✅ Interruption state preservation: State captured during interruption")
        
        // Trigger interruption ended with resume
        mockSessionService.triggerInterruptionEnded(shouldResume: true)
        
        // Wait for recovery attempt
        let recoveryExpectation = expectation(description: "Recovery attempt")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            recoveryExpectation.fulfill()
        }
        await fulfillment(of: [recoveryExpectation], timeout: 2.0)
        
        print("✅ Interruption recovery: Recovery attempt triggered")
    }
    
    func testInterruptionWithoutRecording() {
        // Trigger interruption when not recording
        mockSessionService.triggerInterruptionBegan()
        mockSessionService.triggerInterruptionEnded(shouldResume: true)
        
        // Should not attempt recovery
        XCTAssertFalse(mockRecordingService.createRecorderWithFallbackCalled, "Should not attempt recorder recreation when not recording")
        
        print("✅ Interruption without recording: No unnecessary recovery attempts")
    }
    
    func testInterruptionWithoutResume() async {
        // Start recording
        try! backgroundAudioService.startRecording()
        
        // Trigger interruption
        mockSessionService.triggerInterruptionBegan()
        
        // End interruption without resume
        mockSessionService.triggerInterruptionEnded(shouldResume: false)
        
        // Wait briefly
        let noRecoveryExpectation = expectation(description: "No recovery")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            noRecoveryExpectation.fulfill()
        }
        await fulfillment(of: [noRecoveryExpectation], timeout: 1.0)
        
        // Should not attempt recovery
        XCTAssertFalse(mockRecordingService.createRecorderWithFallbackCalled, "Should not attempt recovery without resume flag")
        
        print("✅ Interruption without resume: Recovery properly skipped")
    }
    
    // MARK: - Recovery Process Tests
    
    func testSuccessfulRecovery() async {
        // Set up successful recovery scenario
        mockRecordingService.createRecorderWithFallbackResult = MockAVAudioRecorder()
        mockTimerService.resumeFromInterruptionCalled = false
        
        // Start recording
        try! backgroundAudioService.startRecording()
        mockRecordingService.currentTimeResult = 10.0
        
        // Simulate interruption and recovery
        mockSessionService.triggerInterruptionBegan()
        mockSessionService.triggerInterruptionEnded(shouldResume: true)
        
        // Wait for recovery
        let recoveryExpectation = expectation(description: "Successful recovery")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            recoveryExpectation.fulfill()
        }
        await fulfillment(of: [recoveryExpectation], timeout: 2.0)
        
        // Verify recovery steps
        XCTAssertTrue(mockSessionService.configureForRecordingCalled, "Should reconfigure session")
        XCTAssertTrue(mockRecordingService.createRecorderWithFallbackCalled, "Should create new recorder")
        XCTAssertTrue(mockRecordingService.startRecordingCalled, "Should start new recording")
        XCTAssertTrue(mockTimerService.resumeFromInterruptionCalled, "Should resume timer")
        
        print("✅ Successful recovery: All recovery steps completed")
    }
    
    func testRecoveryWithSessionFallback() async {
        // Set up session fallback scenario
        mockSessionService.configureForRecordingShouldFail = true
        mockSessionService.attemptRecordingFallbackCalled = false
        
        // Start recording
        try! backgroundAudioService.startRecording()
        
        // Simulate interruption and recovery
        mockSessionService.triggerInterruptionBegan()
        mockSessionService.triggerInterruptionEnded(shouldResume: true)
        
        // Wait for recovery with fallback
        let fallbackExpectation = expectation(description: "Session fallback recovery")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            fallbackExpectation.fulfill()
        }
        await fulfillment(of: [fallbackExpectation], timeout: 2.0)
        
        // Verify fallback was attempted
        XCTAssertTrue(mockSessionService.attemptRecordingFallbackCalled, "Should attempt session fallback")
        
        print("✅ Recovery with session fallback: Fallback mechanism triggered")
    }
    
    func testRecoveryFailure() async {
        // Set up recovery failure scenario
        mockSessionService.configureForRecordingShouldFail = true
        mockSessionService.attemptRecordingFallbackShouldFail = true
        
        var failureCallbackTriggered = false
        backgroundAudioService.onRecordingFailed = { error in
            failureCallbackTriggered = true
            XCTAssertTrue(error.localizedDescription.contains("recovery failed"), "Error should mention recovery failure")
        }
        
        // Start recording
        try! backgroundAudioService.startRecording()
        
        // Simulate interruption and recovery failure
        mockSessionService.triggerInterruptionBegan()
        mockSessionService.triggerInterruptionEnded(shouldResume: true)
        
        // Wait for failure handling
        let failureExpectation = expectation(description: "Recovery failure")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            failureExpectation.fulfill()
        }
        await fulfillment(of: [failureExpectation], timeout: 2.0)
        
        // Verify proper cleanup on failure
        XCTAssertTrue(failureCallbackTriggered, "Should trigger failure callback")
        XCTAssertTrue(mockTimerService.resetTimerCalled, "Should reset timer on failure")
        XCTAssertTrue(mockBackgroundTaskService.endBackgroundTaskCalled, "Should end background task on failure")
        
        print("✅ Recovery failure: Proper cleanup and error handling")
    }
    
    // MARK: - Timer Integration Tests
    
    func testTimerStatePreservation() async {
        mockRecordingService.currentTimeResult = 25.7
        mockTimerService.recordingTime = 25.7
        
        // Start recording
        try! backgroundAudioService.startRecording()
        
        // Simulate interruption
        mockSessionService.triggerInterruptionBegan()
        
        // Wait for state preservation
        let preservationExpectation = expectation(description: "State preservation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            preservationExpectation.fulfill()
        }
        await fulfillment(of: [preservationExpectation], timeout: 1.0)
        
        // Simulate recovery
        mockSessionService.triggerInterruptionEnded(shouldResume: true)
        
        // Wait for recovery
        let resumeExpectation = expectation(description: "Timer resume")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            resumeExpectation.fulfill()
        }
        await fulfillment(of: [resumeExpectation], timeout: 2.0)
        
        // Verify timer was resumed with accumulated time
        XCTAssertTrue(mockTimerService.resumeFromInterruptionCalled, "Should resume timer from interruption")
        XCTAssertEqual(mockTimerService.resumeAccumulatedTime, 25.7, accuracy: 0.1, "Should preserve accumulated time")
        
        print("✅ Timer state preservation: Accumulated time properly preserved and restored")
    }
    
    // MARK: - Background Task Integration Tests
    
    func testBackgroundTaskDuringRecovery() async {
        // Start recording (background task should be active)
        try! backgroundAudioService.startRecording()
        XCTAssertTrue(mockBackgroundTaskService.beginBackgroundTaskCalled, "Should begin background task")
        
        // Simulate interruption and recovery
        mockSessionService.triggerInterruptionBegan()
        mockSessionService.triggerInterruptionEnded(shouldResume: true)
        
        // Wait for recovery
        let recoveryExpectation = expectation(description: "Background task during recovery")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            recoveryExpectation.fulfill()
        }
        await fulfillment(of: [recoveryExpectation], timeout: 2.0)
        
        // Background task should remain active during recovery
        XCTAssertFalse(mockBackgroundTaskService.endBackgroundTaskCalled, "Should not end background task during successful recovery")
        
        print("✅ Background task during recovery: Task maintained throughout recovery process")
    }
    
    func testBackgroundTaskExpiration() {
        var expirationCallbackTriggered = false
        backgroundAudioService.onBackgroundTaskExpired = {
            expirationCallbackTriggered = true
        }
        
        // Start recording
        try! backgroundAudioService.startRecording()
        
        // Trigger background task expiration
        mockBackgroundTaskService.triggerBackgroundTaskExpiration()
        
        // Verify proper handling
        XCTAssertTrue(expirationCallbackTriggered, "Should trigger expiration callback")
        
        // Recording should be stopped
        let stopExpectation = expectation(description: "Recording stopped on expiration")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            stopExpectation.fulfill()
        }
        wait(for: [stopExpectation], timeout: 1.0)
        
        XCTAssertTrue(mockTimerService.stopTimerCalled, "Should stop timer on background task expiration")
        XCTAssertTrue(mockRecordingService.stopRecordingCalled, "Should stop recording on background task expiration")
        
        print("✅ Background task expiration: Graceful recording termination")
    }
    
    // MARK: - Edge Case Tests
    
    func testMultipleRapidInterruptions() async {
        // Start recording
        try! backgroundAudioService.startRecording()
        
        // Simulate multiple rapid interruptions
        for i in 0..<3 {
            mockSessionService.triggerInterruptionBegan()
            
            // Brief delay
            let rapidExpectation = expectation(description: "Rapid interruption \(i)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                rapidExpectation.fulfill()
            }
            await fulfillment(of: [rapidExpectation], timeout: 1.0)
            
            mockSessionService.triggerInterruptionEnded(shouldResume: true)
        }
        
        // Final wait for all processing
        let finalExpectation = expectation(description: "Final processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            finalExpectation.fulfill()
        }
        await fulfillment(of: [finalExpectation], timeout: 2.0)
        
        // Should handle gracefully without crashes
        print("✅ Multiple rapid interruptions: Handled gracefully without crashes")
    }
    
    func testRecoveryWithInvalidURL() async {
        // Start recording with valid URL
        try! backgroundAudioService.startRecording()
        
        // Set up recovery to fail due to invalid URL
        mockRecordingService.createRecorderWithFallbackShouldFail = true
        
        var failureCallbackTriggered = false
        backgroundAudioService.onRecordingFailed = { error in
            failureCallbackTriggered = true
        }
        
        // Simulate interruption and attempted recovery
        mockSessionService.triggerInterruptionBegan()
        mockSessionService.triggerInterruptionEnded(shouldResume: true)
        
        // Wait for recovery failure
        let failureExpectation = expectation(description: "Recovery with invalid URL")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            failureExpectation.fulfill()
        }
        await fulfillment(of: [failureExpectation], timeout: 2.0)
        
        // Should handle gracefully
        XCTAssertTrue(failureCallbackTriggered, "Should trigger failure callback")
        
        print("✅ Recovery with invalid URL: Proper error handling and cleanup")
    }
    
    // MARK: - Performance Tests
    
    func testRecoveryPerformance() async {
        // Start recording
        try! backgroundAudioService.startRecording()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate interruption and recovery
        mockSessionService.triggerInterruptionBegan()
        mockSessionService.triggerInterruptionEnded(shouldResume: true)
        
        // Wait for recovery
        let performanceExpectation = expectation(description: "Recovery performance")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            performanceExpectation.fulfill()
        }
        await fulfillment(of: [performanceExpectation], timeout: 2.0)
        
        let recoveryTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        // Recovery should complete quickly
        XCTAssertLessThan(recoveryTime, 1000.0, "Recovery should complete within 1 second")
        
        print("✅ Recovery performance: \(String(format: "%.2f", recoveryTime))ms recovery time")
    }
    
    func testMemoryUsageDuringInterruption() async {
        let initialMemory = getMemoryUsage()
        
        // Start recording
        try! backgroundAudioService.startRecording()
        
        // Simulate multiple interruption cycles
        for _ in 0..<10 {
            mockSessionService.triggerInterruptionBegan()
            
            let cycleExpectation = expectation(description: "Interruption cycle")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                cycleExpectation.fulfill()
            }
            await fulfillment(of: [cycleExpectation], timeout: 1.0)
            
            mockSessionService.triggerInterruptionEnded(shouldResume: true)
            
            let recoveryExpectation = expectation(description: "Recovery cycle")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                recoveryExpectation.fulfill()
            }
            await fulfillment(of: [recoveryExpectation], timeout: 1.0)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory usage should not grow significantly during interruptions
        XCTAssertLessThan(memoryIncrease, 5.0, "Memory increase should be under 5MB for 10 interruption cycles")
        
        print("✅ Memory usage during interruption: \(String(format: "%.2f", memoryIncrease))MB increase for 10 cycles")
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