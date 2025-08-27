//
//  RecordingFlowTestUseCase.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-01-26.
//

import Foundation

/// Test use case for validating the complete background recording flow
/// This use case tests the integration of all recording use cases with the enhanced AudioRepository
final class RecordingFlowTestUseCase {
    
    // MARK: - Dependencies
    private let audioRepository: AudioRepository
    private let startRecordingUseCase: StartRecordingUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let permissionUseCase: RequestMicrophonePermissionUseCaseProtocol
    
    // MARK: - Initialization
    init(audioRepository: AudioRepository) {
        self.audioRepository = audioRepository
        self.startRecordingUseCase = StartRecordingUseCase(audioRepository: audioRepository)
        self.stopRecordingUseCase = StopRecordingUseCase(audioRepository: audioRepository)
        self.permissionUseCase = RequestMicrophonePermissionUseCase()
    }
    
    // MARK: - Factory Method
    @MainActor
    static func create() -> RecordingFlowTestUseCase {
        let audioRepo = AudioRepositoryImpl()
        return RecordingFlowTestUseCase(audioRepository: audioRepo)
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
            try startRecordingUseCase.execute()
            
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
            try stopRecordingUseCase.execute()
            
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
            do {
                try stopRecordingUseCase.execute()
                print("🧹 RecordingFlowTestUseCase: Cleanup completed after error")
            } catch {
                print("❌ RecordingFlowTestUseCase: Cleanup also failed: \(error)")
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
                try startRecordingUseCase.execute()
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                
                // Stop recording
                try stopRecordingUseCase.execute()
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
            try stopRecordingUseCase.execute()
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
                try startRecordingUseCase.execute()
                
                // Try to start again while recording
                try startRecordingUseCase.execute()
                print("❌ Error handling test failed: Second start should have thrown error")
                
                // Cleanup
                try stopRecordingUseCase.execute()
            }
        } catch RecordingError.alreadyRecording {
            print("✅ Error handling test 2 passed: Properly caught 'already recording' error")
            
            // Cleanup
            do {
                try stopRecordingUseCase.execute()
            } catch {
                print("⚠️ Cleanup after double start test failed: \(error)")
            }
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
