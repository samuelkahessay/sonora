#if canImport(SwiftData)
@testable import Sonora
import Combine
import SwiftData
import XCTest

@MainActor
final class TranscriptionRepositoryImplTests: XCTestCase {

    // MARK: - Test Infrastructure

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            MemoModel.self,
            TranscriptionModel.self,
            AutoTitleJobModel.self,
            AnalysisResultModel.self
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

    // MARK: - Save and Get Tests

    func test_saveAndGetTranscriptionState_Success() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        // Save in progress
        await repository.saveTranscriptionState(.inProgress, for: memo.id)

        // Get
        let retrieved = await repository.getTranscriptionState(for: memo.id)

        XCTAssertTrue(retrieved.isInProgress)
    }

    func test_saveTranscriptionText_SavesCompletedState() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        await repository.saveTranscriptionText("Test transcription text", for: memo.id)

        let text = await repository.getTranscriptionText(for: memo.id)
        XCTAssertEqual(text, "Test transcription text")

        let state = await repository.getTranscriptionState(for: memo.id)
        XCTAssertTrue(state.isCompleted)
    }

    func test_getTranscriptionState_NonExistent_ReturnsNotStarted() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)

        let state = await repository.getTranscriptionState(for: UUID())

        XCTAssertTrue(state.isNotStarted)
    }

    // MARK: - State Transition Tests

    func test_stateTransitions_NotStartedToCompleted() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        // Initial state
        var state = await repository.getTranscriptionState(for: memo.id)
        XCTAssertTrue(state.isNotStarted)

        // To in progress
        await repository.saveTranscriptionState(.inProgress, for: memo.id)
        state = await repository.getTranscriptionState(for: memo.id)
        XCTAssertTrue(state.isInProgress)

        // To completed
        await repository.saveTranscriptionState(.completed("Final text"), for: memo.id)
        state = await repository.getTranscriptionState(for: memo.id)
        XCTAssertTrue(state.isCompleted)
        XCTAssertEqual(state.text, "Final text")
    }

    func test_stateTransitions_InProgressToFailed() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        await repository.saveTranscriptionState(.inProgress, for: memo.id)
        await repository.saveTranscriptionState(.failed("Network error"), for: memo.id)

        let state = await repository.getTranscriptionState(for: memo.id)
        XCTAssertTrue(state.isFailed)
        XCTAssertEqual(state.errorMessage, "Network error")
    }

    // MARK: - Publisher Tests

    func test_stateChangesPublisher_EmitsOnSave() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        var receivedChanges: [TranscriptionStateChange] = []
        let cancellable = repository.stateChangesPublisher
            .sink { change in
                receivedChanges.append(change)
            }

        // Save state
        await repository.saveTranscriptionState(.inProgress, for: memo.id)

        XCTAssertEqual(receivedChanges.count, 1)
        XCTAssertEqual(receivedChanges[0].memoId, memo.id)
        XCTAssertTrue(receivedChanges[0].currentState.isInProgress)
        XCTAssertNil(receivedChanges[0].previousState)

        cancellable.cancel()
    }

    func test_stateChangesPublisher_EmitsOnUpdate() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        var receivedChanges: [TranscriptionStateChange] = []
        let cancellable = repository.stateChangesPublisher
            .sink { change in
                receivedChanges.append(change)
            }

        // Initial save
        await repository.saveTranscriptionState(.inProgress, for: memo.id)
        // Update
        await repository.saveTranscriptionState(.completed("Done"), for: memo.id)

        XCTAssertEqual(receivedChanges.count, 2)
        XCTAssertTrue(receivedChanges[0].currentState.isInProgress)
        XCTAssertTrue(receivedChanges[1].currentState.isCompleted)
        XCTAssertTrue(receivedChanges[1].previousState?.isInProgress ?? false)

        cancellable.cancel()
    }

    func test_stateChangesPublisher_ForSpecificMemo_OnlyEmitsRelevantChanges() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo1 = try makeTestMemo(in: context, id: UUID())
        let memo2 = try makeTestMemo(in: context, id: UUID())

        var memo1Changes: [TranscriptionStateChange] = []
        let cancellable = repository.stateChangesPublisher(for: memo1.id)
            .sink { change in
                memo1Changes.append(change)
            }

        // Save for both memos
        await repository.saveTranscriptionState(.inProgress, for: memo1.id)
        await repository.saveTranscriptionState(.inProgress, for: memo2.id)
        await repository.saveTranscriptionState(.completed("Done"), for: memo1.id)

        // Should only receive changes for memo1
        XCTAssertEqual(memo1Changes.count, 2)
        XCTAssertTrue(memo1Changes.allSatisfy { $0.memoId == memo1.id })

        cancellable.cancel()
    }

    func test_stateChangesPublisher_EmitsOnGetForNonExistent() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memoId = UUID()

        var receivedChanges: [TranscriptionStateChange] = []
        let cancellable = repository.stateChangesPublisher
            .sink { change in
                receivedChanges.append(change)
            }

        // Getting non-existent state should emit discovery event
        _ = await repository.getTranscriptionState(for: memoId)

        XCTAssertEqual(receivedChanges.count, 1)
        XCTAssertEqual(receivedChanges[0].memoId, memoId)
        XCTAssertTrue(receivedChanges[0].currentState.isNotStarted)

        cancellable.cancel()
    }

    // MARK: - Delete Tests

    func test_deleteTranscriptionData_RemovesState() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        await repository.saveTranscriptionState(.completed("Test"), for: memo.id)
        let stateBeforeDeletion = await repository.getTranscriptionState(for: memo.id)
        XCTAssertTrue(stateBeforeDeletion.isCompleted)

        await repository.deleteTranscriptionData(for: memo.id)

        // Should return notStarted after deletion
        let state = await repository.getTranscriptionState(for: memo.id)
        XCTAssertTrue(state.isNotStarted)
    }

    func test_deleteTranscriptionData_EmitsStateChangeEvent() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        await repository.saveTranscriptionState(.completed("Test"), for: memo.id)

        var receivedChanges: [TranscriptionStateChange] = []
        let cancellable = repository.stateChangesPublisher
            .sink { change in
                receivedChanges.append(change)
            }

        await repository.deleteTranscriptionData(for: memo.id)

        // Should emit deletion event
        XCTAssertEqual(receivedChanges.count, 1)
        XCTAssertTrue(receivedChanges[0].currentState.isNotStarted)
        XCTAssertTrue(receivedChanges[0].previousState?.isCompleted ?? false)

        cancellable.cancel()
    }

    // MARK: - Batch Retrieval Tests

    func test_getTranscriptionStates_ReturnsBatchResults() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)

        let memo1 = try makeTestMemo(in: context, id: UUID())
        let memo2 = try makeTestMemo(in: context, id: UUID())
        let memo3 = try makeTestMemo(in: context, id: UUID())

        await repository.saveTranscriptionState(.completed("Text 1"), for: memo1.id)
        await repository.saveTranscriptionState(.inProgress, for: memo2.id)
        await repository.saveTranscriptionState(.failed("Error"), for: memo3.id)

        let states = await repository.getTranscriptionStates(for: [memo1.id, memo2.id, memo3.id])

        XCTAssertEqual(states.count, 3)
        XCTAssertTrue(states[memo1.id]?.isCompleted ?? false)
        XCTAssertTrue(states[memo2.id]?.isInProgress ?? false)
        XCTAssertTrue(states[memo3.id]?.isFailed ?? false)
    }

    func test_getTranscriptionStates_EmptyArray_ReturnsEmpty() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)

        let states = await repository.getTranscriptionStates(for: [])

        XCTAssertTrue(states.isEmpty)
    }

    func test_getTranscriptionStates_UsesCacheFirst() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        // Save and ensure it's cached
        await repository.saveTranscriptionState(.completed("Cached"), for: memo.id)

        // Batch retrieval should use cache
        let states = await repository.getTranscriptionStates(for: [memo.id])

        XCTAssertEqual(states.count, 1)
        XCTAssertEqual(states[memo.id]?.text, "Cached")
    }

    // MARK: - Cache Tests

    func test_clearTranscriptionCache_RemovesAllCachedStates() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        await repository.saveTranscriptionState(.completed("Test"), for: memo.id)

        // Verify cached
        let cachedStatesBefore = await repository.transcriptionStates
        XCTAssertFalse(cachedStatesBefore.isEmpty)

        await repository.clearTranscriptionCache()

        // Cache should be empty
        let cachedStatesAfter = await repository.transcriptionStates
        XCTAssertTrue(cachedStatesAfter.isEmpty)

        // But data should still be in persistent store
        let state = await repository.getTranscriptionState(for: memo.id)
        XCTAssertTrue(state.isCompleted)
    }

    // MARK: - Metadata Tests

    func test_saveAndGetTranscriptionMetadata() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        let metadata = TranscriptionMetadata(
            memoId: memo.id,
            state: "completed",
            text: "Test text",
            originalText: "Original text",
            lastUpdated: Date(),
            detectedLanguage: "en"
        )

        await repository.saveTranscriptionMetadata(metadata, for: memo.id)

        let retrieved = await repository.getTranscriptionMetadata(for: memo.id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.memoId, memo.id)
        XCTAssertEqual(retrieved?.text, "Test text")
        XCTAssertEqual(retrieved?.detectedLanguage, "en")
    }

    func test_getTranscriptionMetadata_NonExistent_ReturnsNil() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)

        let metadata = await repository.getTranscriptionMetadata(for: UUID())

        XCTAssertNil(metadata)
    }

    // MARK: - TranscriptionStates Dictionary Tests

    func test_transcriptionStates_ReflectsCurrentState() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        let initialStates = await repository.transcriptionStates
        XCTAssertTrue(initialStates.isEmpty)

        await repository.saveTranscriptionState(.inProgress, for: memo.id)

        let updatedStates = await repository.transcriptionStates
        XCTAssertEqual(updatedStates.count, 1)
        XCTAssertTrue(updatedStates[memo.id.uuidString]?.isInProgress ?? false)
    }

    func test_transcriptionStates_UpdatesOnStateChange() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)
        let memo = try makeTestMemo(in: context)

        await repository.saveTranscriptionState(.inProgress, for: memo.id)
        let statesAfterInProgress = await repository.transcriptionStates
        XCTAssertTrue(statesAfterInProgress[memo.id.uuidString]?.isInProgress ?? false)

        await repository.saveTranscriptionState(.completed("Done"), for: memo.id)
        let statesAfterCompletion = await repository.transcriptionStates
        XCTAssertTrue(statesAfterCompletion[memo.id.uuidString]?.isCompleted ?? false)
    }

    // MARK: - Edge Cases

    func test_multipleConcurrentStateChanges() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)

        let memo1 = try makeTestMemo(in: context, id: UUID())
        let memo2 = try makeTestMemo(in: context, id: UUID())
        let memo3 = try makeTestMemo(in: context, id: UUID())

        var allChanges: [TranscriptionStateChange] = []
        let cancellable = repository.stateChangesPublisher
            .sink { change in
                allChanges.append(change)
            }

        // Rapid state changes
        await repository.saveTranscriptionState(.inProgress, for: memo1.id)
        await repository.saveTranscriptionState(.inProgress, for: memo2.id)
        await repository.saveTranscriptionState(.completed("Done 1"), for: memo1.id)
        await repository.saveTranscriptionState(.inProgress, for: memo3.id)
        await repository.saveTranscriptionState(.completed("Done 2"), for: memo2.id)

        XCTAssertEqual(allChanges.count, 5)
        XCTAssertEqual(Set(allChanges.map { $0.memoId }).count, 3)

        cancellable.cancel()
    }

    func test_saveTranscriptionStateWithoutMemo_StillWorks() async throws {
        let context = try makeInMemoryContext()
        let repository = TranscriptionRepositoryImpl(context: context)

        // Save for non-existent memo
        let orphanId = UUID()
        await repository.saveTranscriptionState(.completed("Orphan text"), for: orphanId)

        let state = await repository.getTranscriptionState(for: orphanId)
        XCTAssertTrue(state.isCompleted)
        XCTAssertEqual(state.text, "Orphan text")
    }
}
#endif
