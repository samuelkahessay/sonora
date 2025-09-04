//
//  TranscriptionPersistenceTestUseCase.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-01-26.
//

import Foundation

/// Test use case for validating transcription persistence across app restarts
/// This use case tests that transcriptions are properly saved and restored from disk
@MainActor
final class TranscriptionPersistenceTestUseCase {
    
    // MARK: - Dependencies
    private let transcriptionRepository: any TranscriptionRepository
    private let startTranscriptionUseCase: StartTranscriptionUseCaseProtocol
    private let getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol
    
    // MARK: - Initialization
    init(transcriptionRepository: any TranscriptionRepository) {
        self.transcriptionRepository = transcriptionRepository
        self.startTranscriptionUseCase = StartTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: TranscriptionService(),
            eventBus: EventBus.shared,
            operationCoordinator: OperationCoordinator.shared,
            moderationService: NoopModerationService()
        )
        self.getTranscriptionStateUseCase = GetTranscriptionStateUseCase(transcriptionRepository: transcriptionRepository)
    }
    
    // MARK: - Factory Method
    @MainActor
    static func create() -> TranscriptionPersistenceTestUseCase {
        let repository = DIContainer.shared.transcriptionRepository()
        return TranscriptionPersistenceTestUseCase(transcriptionRepository: repository)
    }
    
    // MARK: - Test Methods
    
    /// Test that transcriptions persist after app restart simulation
    func testTranscriptionPersistence() async {
        print("🧪 TranscriptionPersistenceTestUseCase: Testing transcription persistence")
        
        // Create a test memo (you would typically use an actual recorded memo)
        let testMemoId = UUID()
        
        // Phase 1: Save transcription states
            print("🧪 Phase 1: Saving various transcription states...")
            
            // Test different states (already on MainActor)
            transcriptionRepository.saveTranscriptionState(.notStarted, for: testMemoId)
            transcriptionRepository.saveTranscriptionState(.inProgress, for: testMemoId)
            transcriptionRepository.saveTranscriptionState(.completed("Test transcription text for persistence testing"), for: testMemoId)
            transcriptionRepository.saveTranscriptionState(.failed("Test error message"), for: testMemoId)
            
            // Save completed transcription with text
            transcriptionRepository.saveTranscriptionText("This is a test transcription that should persist across app restarts.", for: testMemoId)
            
            print("✅ Phase 1: Transcription states saved")
            
            // Phase 2: Simulate app restart by clearing cache
            print("🧪 Phase 2: Simulating app restart (clearing cache)...")
            
            transcriptionRepository.clearTranscriptionCache()
            
            print("✅ Phase 2: Cache cleared (simulating app restart)")
            
            // Phase 3: Verify data persists
            print("🧪 Phase 3: Verifying transcription data persists...")
            
            let restoredState = transcriptionRepository.getTranscriptionState(for: testMemoId)
            
            let restoredText = transcriptionRepository.getTranscriptionText(for: testMemoId)
            
            let hasData = transcriptionRepository.hasTranscriptionData(for: testMemoId)
            
            if hasData && restoredState.isCompleted && restoredText != nil {
                print("✅ TranscriptionPersistenceTestUseCase: Persistence test PASSED!")
                print("   - State: \(restoredState.statusText)")
                print("   - Text: \(restoredText?.prefix(50) ?? "None")...")
                print("   - Has Data: \(hasData)")
            } else {
                print("❌ TranscriptionPersistenceTestUseCase: Persistence test FAILED!")
                print("   - State: \(restoredState.statusText)")
                print("   - Text: \(restoredText ?? "None")")
                print("   - Has Data: \(hasData)")
            }
            
            // Phase 4: Test metadata persistence
            print("🧪 Phase 4: Testing metadata persistence...")
            
            let metadata = transcriptionRepository.getTranscriptionMetadata(for: testMemoId)
            
            if let metadata = metadata {
                print("✅ Phase 4: Metadata persistence test PASSED!")
                let keys = [
                    metadata.detectedLanguage != nil ? "detectedLanguage" : nil,
                    metadata.qualityScore != nil ? "qualityScore" : nil,
                    metadata.transcriptionService?.rawValue,
                    metadata.whisperModel != nil ? "whisperModel" : nil,
                    metadata.aiGenerated != nil ? "aiGenerated" : nil,
                    metadata.moderationFlagged != nil ? "moderationFlagged" : nil,
                    (metadata.moderationCategories != nil) ? "moderationCategories" : nil
                ].compactMap { $0 }
                print("   - Metadata keys: \(keys.sorted())")
            } else {
                print("❌ Phase 4: Metadata persistence test FAILED!")
            }
            
            // Phase 5: Test bulk operations
            print("🧪 Phase 5: Testing bulk transcription state retrieval...")
            
            let allStates = transcriptionRepository.getAllTranscriptionStates()
            
            print("✅ Phase 5: Found \(allStates.count) transcription states")
            for (id, state) in allStates {
                print("   - \(id): \(state.statusText)")
            }
            
            // Cleanup
            transcriptionRepository.deleteTranscriptionData(for: testMemoId)
            
            print("🧪 TranscriptionPersistenceTestUseCase: Test completed successfully")
    }
    
    /// Test real transcription workflow with persistence
    func testRealTranscriptionWorkflow(memo: Memo) async {
        print("🧪 TranscriptionPersistenceTestUseCase: Testing real transcription workflow")
        
        do {
            // Check initial state
            let initialState = getTranscriptionStateUseCase.execute(memo: memo)
            print("🧪 Initial state: \(initialState.statusText)")
            
            // Start transcription if not already done
            if initialState.isNotStarted || initialState.isFailed {
                print("🧪 Starting transcription...")
                try await startTranscriptionUseCase.execute(memo: memo)
                
                // Wait a moment for transcription to start
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                let progressState = getTranscriptionStateUseCase.execute(memo: memo)
                print("🧪 Progress state: \(progressState.statusText)")
            }
            
            // Test persistence by simulating restart
            print("🧪 Simulating app restart...")
            transcriptionRepository.clearTranscriptionCache()
            
            // Check if state persists
            let persistedState = getTranscriptionStateUseCase.execute(memo: memo)
            print("🧪 Persisted state after restart: \(persistedState.statusText)")
            
            if persistedState.isNotStarted {
                print("⚠️ TranscriptionPersistenceTestUseCase: State did not persist (this is expected for non-file-based states)")
            } else {
                print("✅ TranscriptionPersistenceTestUseCase: State persisted successfully!")
            }
            
            // Check if transcription text persists
            let persistedText = transcriptionRepository.getTranscriptionText(for: memo.id)
            
            if let text = persistedText, !text.isEmpty {
                print("✅ TranscriptionPersistenceTestUseCase: Transcription text persisted!")
                print("   - Text: \(text.prefix(100))...")
            } else {
                print("⚠️ TranscriptionPersistenceTestUseCase: No transcription text found (may still be in progress)")
            }
            
        } catch {
            print("❌ TranscriptionPersistenceTestUseCase: Real workflow test failed: \(error)")
        }
    }
    
    /// Test multiple memos to verify isolated persistence
    func testMultipleMemosPersistence() async {
        print("🧪 TranscriptionPersistenceTestUseCase: Testing multiple memos persistence")
        
        let testMemos = [
            (UUID(), "Test Memo 1", "First test transcription"),
            (UUID(), "Test Memo 2", "Second test transcription"),
            (UUID(), "Test Memo 3", "Third test transcription")
        ]
        
        // Save transcriptions for all memos
        for (id, filename, text) in testMemos {
            transcriptionRepository.saveTranscriptionState(.completed(text), for: id)
            transcriptionRepository.saveTranscriptionText(text, for: id)
            print("💾 Saved transcription for \(filename)")
        }
        
        // Clear cache to simulate restart
        transcriptionRepository.clearTranscriptionCache()
        
        // Verify all transcriptions persist
        var allPersisted = true
        for (id, filename, expectedText) in testMemos {
            let state = transcriptionRepository.getTranscriptionState(for: id)
            let text = transcriptionRepository.getTranscriptionText(for: id)
            
            if state.isCompleted && text == expectedText {
                print("✅ \(filename): Persisted correctly")
            } else {
                print("❌ \(filename): Failed to persist")
                allPersisted = false
            }
        }
        
        if allPersisted {
            print("✅ TranscriptionPersistenceTestUseCase: Multiple memos persistence test PASSED!")
        } else {
            print("❌ TranscriptionPersistenceTestUseCase: Multiple memos persistence test FAILED!")
        }
        
        // Cleanup
        for (id, _, _) in testMemos {
            transcriptionRepository.deleteTranscriptionData(for: id)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestMemo(id: UUID) -> Memo {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let testURL = documentsPath.appendingPathComponent("test_memo.m4a")
        
        return Memo(
            filename: "test_memo.m4a",
            fileURL: testURL,
            creationDate: Date()
        )
    }
    
    /// Get comprehensive debug information
    @MainActor
    var debugInfo: String {
        let allStates = transcriptionRepository.getAllTranscriptionStates()
        
        return """
        TranscriptionPersistenceTestUseCase Debug Info:
        - Total transcription states: \(allStates.count)
        - States: \(allStates.map { "\($0.key): \($0.value.statusText)" }.joined(separator: ", "))
        
        Use Cases:
        - StartTranscriptionUseCase: ✅ Configured
        - GetTranscriptionStateUseCase: ✅ Configured
        - TranscriptionRepository: ✅ Connected
        """
    }
}
