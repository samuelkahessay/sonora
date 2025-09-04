//
//  RecordingFlowTestUseCase.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-01-26.
//

import Foundation

/// Test use case for validating the complete background recording flow
/// This use case tests the integration of all recording use cases with the enhanced AudioRepository
@MainActor
final class RecordingFlowTestUseCase {
    
    // MARK: - Dependencies
    private let audioRepository: any AudioRepository
    private let startRecordingUseCase: StartRecordingUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let permissionUseCase: RequestMicrophonePermissionUseCaseProtocol
    
    // MARK: - State Management
    private var currentMemoId: UUID?
    
    // MARK: - Initialization
    init(audioRepository: any AudioRepository, operationCoordinator: any OperationCoordinatorProtocol) {
        self.audioRepository = audioRepository
        self.startRecordingUseCase = StartRecordingUseCase(audioRepository: audioRepository, operationCoordinator: operationCoordinator)
        self.stopRecordingUseCase = StopRecordingUseCase(audioRepository: audioRepository, operationCoordinator: operationCoordinator)
        self.permissionUseCase = RequestMicrophonePermissionUseCase()
    }
    
    // MARK: - Factory Method
    @MainActor
    static func create() -> RecordingFlowTestUseCase {
        let backgroundService = BackgroundAudioService()
        let audioRepo = AudioRepositoryImpl(backgroundAudioService: backgroundService)
        return RecordingFlowTestUseCase(
            audioRepository: audioRepo,
            operationCoordinator: DIContainer.shared.operationCoordinator()
        )
    }
    
    // MARK: - Test Execution
    
    /// Test the complete recording flow with background support
    func testCompleteRecordingFlow() async {
        print("🧪 RecordingFlowTestUseCase: Starting complete recording flow test")
        
        do {
            // Phase 1: Permission Check
            print("🧪 Phase 1: Checking microphone permissions...")
            let hasPermission = await permissionUseCase.execute()
            
            guard hasPermission.allowsRecording else {
                print("❌ RecordingFlowTestUseCase: Test failed - no microphone permission")
                return
            }
            
            print("✅ Phase 1: Microphone permission granted")
            
            // Phase 2: Start Recording
            print("🧪 Phase 2: Starting background recording...")
            currentMemoId = try await startRecordingUseCase.execute()
            
            guard currentMemoId != nil else {
                print("❌ RecordingFlowTestUseCase: Test failed - no memoId returned from start recording")
                return
            }
            
            // Give a moment for async recording to start
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            await MainActor.run {
                if let audioRepoImpl = audioRepository as? AudioRepositoryImpl {
                    print("✅ Phase 2: Recording started successfully")
                    print("   - Recording: \(audioRepoImpl.isRecording)")
                    print("   - Background Task: \(audioRepoImpl.isBackgroundTaskActive)")
                }
            }
            
            // Phase 3: Simulate Background Operation
            print("🧪 Phase 3: Simulating background recording (5 seconds)...")
            print("   💡 Lock your device now to test background recording!")
            
            for i in 1...5 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                await MainActor.run {
                    if let audioRepoImpl = audioRepository as? AudioRepositoryImpl {
                        print("   - Second \(i): Recording=\(audioRepoImpl.isRecording), Time=\(String(format: "%.1f", audioRepoImpl.recordingTime))s, Background=\(audioRepoImpl.isBackgroundTaskActive)")
                    }
                }
            }
            
            // Phase 4: Stop Recording
            print("🧪 Phase 4: Stopping recording...")
            guard let memoId = currentMemoId else {
                print("❌ RecordingFlowTestUseCase: Cannot stop recording - no active memoId")
                return
            }
            try await stopRecordingUseCase.execute(memoId: memoId)
            currentMemoId = nil
            
            await MainActor.run {
                if let audioRepoImpl = audioRepository as? AudioRepositoryImpl {
                    print("✅ Phase 4: Recording stopped successfully")
                    print("   - Recording: \(audioRepoImpl.isRecording)")
                    print("   - Background Task: \(audioRepoImpl.isBackgroundTaskActive)")
                }
            }
            
            // Phase 5: Validation
            print("🧪 Phase 5: Final validation...")
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms for cleanup
            
            await MainActor.run {
                if let audioRepoImpl = audioRepository as? AudioRepositoryImpl {
                    let finalRecording = audioRepoImpl.isRecording
                    let finalBackgroundTask = audioRepoImpl.isBackgroundTaskActive
                    
                    if !finalRecording && !finalBackgroundTask {
                        print("✅ RecordingFlowTestUseCase: All tests passed!")
                        print("   - Recording properly stopped")
                        print("   - Background task properly cleaned up")
                        print("   - Resource management successful")
                    } else {
                        print("⚠️ RecordingFlowTestUseCase: Cleanup issues detected")
                        print("   - Final Recording State: \(finalRecording)")
                        print("   - Final Background Task: \(finalBackgroundTask)")
                    }
                }
            }
            
        } catch {
            print("❌ RecordingFlowTestUseCase: Test failed with error: \(error)")
            
            // Cleanup on error
            if let memoId = currentMemoId {
                do {
                    try await stopRecordingUseCase.execute(memoId: memoId)
                    currentMemoId = nil
                    print("🧹 RecordingFlowTestUseCase: Cleanup completed after error")
                } catch {
                    print("❌ RecordingFlowTestUseCase: Cleanup also failed: \(error)")
                }
            }
        }
    }
    
    /// Test rapid start/stop operations to verify debouncing and state management
    func testRapidOperations() async {
        print("🧪 RecordingFlowTestUseCase: Testing rapid start/stop operations")
        
        do {
            // Check permissions first
            let hasPermission = await permissionUseCase.execute()
            guard hasPermission.allowsRecording else {
                print("❌ RecordingFlowTestUseCase: No permission for rapid operations test")
                return
            }
            
            // Test rapid start/stop cycles
            for i in 1...3 {
                print("🧪 Rapid test cycle \(i)")
                
                // Start recording
                let cycleMemoId = try await startRecordingUseCase.execute()
                guard let memoId = cycleMemoId else {
                    print("❌ RecordingFlowTestUseCase: Rapid test failed - no memoId returned for cycle \(i)")
                    return
                }
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                
                // Stop recording
                try await stopRecordingUseCase.execute(memoId: memoId)
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms for cleanup
            }
            
            print("✅ RecordingFlowTestUseCase: Rapid operations test completed successfully")
            
        } catch {
            print("❌ RecordingFlowTestUseCase: Rapid operations test failed: \(error)")
        }
    }
    
    /// Test error handling scenarios
    func testErrorHandling() async {
        print("🧪 RecordingFlowTestUseCase: Testing error handling scenarios")
        
        // Test 1: Try to stop when not recording
        do {
            let dummyMemoId = UUID()
            try await stopRecordingUseCase.execute(memoId: dummyMemoId)
            print("❌ Error handling test failed: Stop should have thrown error")
        } catch RecordingError.notRecording {
            print("✅ Error handling test 1 passed: Properly caught 'not recording' error")
        } catch {
            print("⚠️ Error handling test 1 partial: Caught unexpected error: \(error)")
        }
        
        // Test 2: Try to start without permission (if possible)
        // This test would require temporarily disabling permissions
        
        // Test 3: Try to start twice
        do {
            let hasPermission = await permissionUseCase.execute()
            if hasPermission.allowsRecording {
                let firstStart = try await startRecordingUseCase.execute()
                guard let firstMemoId = firstStart else {
                    print("❌ Error handling test failed: First start returned nil memoId")
                    return
                }
                
                // Try to start again while recording
                let _ = try await startRecordingUseCase.execute()
                print("❌ Error handling test failed: Second start should have thrown error")
                
                // Cleanup
                try await stopRecordingUseCase.execute(memoId: firstMemoId)
            }
        } catch RecordingError.alreadyRecording {
            print("✅ Error handling test 2 passed: Properly caught 'already recording' error")
            
            // Cleanup - we need to find the active memoId or use a reasonable approach
            // Since we can't easily get the memoId here, we'll let the operation coordinator handle cleanup
            print("ℹ️ Cleanup will be handled by operation coordinator timeout")
        } catch {
            print("⚠️ Error handling test 2 partial: Caught unexpected error: \(error)")
        }
        
        print("🧪 RecordingFlowTestUseCase: Error handling tests completed")
    }
    
    /// Get comprehensive debug information
    @MainActor
    var debugInfo: String {
        if let audioRepoImpl = audioRepository as? AudioRepositoryImpl {
            return """
            RecordingFlowTestUseCase Debug Info:
            \(audioRepoImpl.debugInfo)
            
            Use Cases:
            - StartRecordingUseCase: ✅ Configured
            - StopRecordingUseCase: ✅ Configured  
            - PermissionUseCase: ✅ Configured
            """
        } else {
            return "RecordingFlowTestUseCase: AudioRepository does not support enhanced recording"
        }
    }
}
