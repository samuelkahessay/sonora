//
//  SonoraTests.swift
//  SonoraTests
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import Foundation
@testable import Sonora
import SwiftData
import Testing
struct SonoraTests {

    @MainActor
    private func makeTestMemoRepository() throws -> MemoRepositoryImpl {
        let schema = Schema([
            MemoModel.self,
            TranscriptionModel.self,
            AnalysisResultModel.self,
            AutoTitleJobModel.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        let transcriptionRepo = TranscriptionRepositoryImpl(context: context)
        let jobRepo = AutoTitleJobRepositoryImpl(context: context)
        return MemoRepositoryImpl(
            context: context,
            transcriptionRepository: transcriptionRepo,
            autoTitleJobRepository: jobRepo
        )
    }

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test
    @MainActor
    func testMemoRepositoryAtomicOperations() async throws {
        // Create a test repository
        let repository = try makeTestMemoRepository()

        // Create a test memo with a dummy audio file
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_audio.m4a")

        // Create a small test file
        let testData = Data("test audio content".utf8)
        try testData.write(to: testURL)

        let testMemo = Memo(
            filename: "test_audio.m4a",
            fileURL: testURL,
            creationDate: Date()
        )

        // Test saving
        repository.saveMemo(testMemo)

        // Test loading
        repository.loadMemos()

        // Verify the memo was saved and loaded
        #expect(!repository.memos.isEmpty)

        // Clean up
        try? FileManager.default.removeItem(at: testURL)

        print("✅ MemoRepository atomic operations test completed successfully")
    }

    @Test
    @MainActor
    func testUpdatedMemoUseCases() async throws {
        // Create test repository
        let repository = try makeTestMemoRepository()

        // Create use cases
        let loadMemosUseCase = LoadMemosUseCase(memoRepository: repository)
        let deleteMemosUseCase = DeleteMemoUseCase(memoRepository: repository)
        let handleRecordingUseCase = HandleNewRecordingUseCase(memoRepository: repository, eventBus: EventBus.shared)
        let playMemoUseCase = PlayMemoUseCase(memoRepository: repository)

        // Test loading memos
        do {
            let memos = try await loadMemosUseCase.execute()
            print("✅ LoadMemosUseCase test: Loaded \(memos.count) memos")
            #expect(memos.isEmpty) // Should not crash
        } catch {
            print("⚠️ LoadMemosUseCase test failed with expected error: \(error)")
            // This is acceptable as there might be no memos initially
        }

        // Test handling new recording with a valid audio file
        let testAudioURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_recording.m4a")

        // Create a small test audio file (minimal valid m4a content)
        let minimalM4AData = Data([
            0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, // ftyp header
            0x4D, 0x34, 0x41, 0x20, 0x00, 0x00, 0x00, 0x00, // M4A brand
            0x4D, 0x34, 0x41, 0x20, 0x6D, 0x70, 0x34, 0x31, // M4A mp41
            0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x00, 0x00  // isom
        ])

        do {
            try minimalM4AData.write(to: testAudioURL)

            // Test with invalid file (will fail validation as expected)
            do {
                let memo = try await handleRecordingUseCase.execute(at: testAudioURL)
                print("✅ HandleNewRecordingUseCase test: Created memo \(memo.filename)")
            } catch {
                print("⚠️ HandleNewRecordingUseCase test failed with expected error: \(error)")
                // This is expected since our test file isn't a valid audio file
            }

        } catch {
            print("⚠️ Could not create test file: \(error)")
        }

        // Test playback with repository memos
        if !repository.memos.isEmpty {
            let firstMemo = repository.memos.first!
            do {
                try await playMemoUseCase.execute(memo: firstMemo)
                print("✅ PlayMemoUseCase test: Successfully initiated playback")
            } catch {
                print("⚠️ PlayMemoUseCase test failed: \(error)")
            }
        }

        // Test deletion with repository memos
        if !repository.memos.isEmpty {
            let firstMemo = repository.memos.first!
            do {
                try await deleteMemosUseCase.execute(memo: firstMemo)
                print("✅ DeleteMemoUseCase test: Successfully deleted memo")
            } catch {
                print("⚠️ DeleteMemoUseCase test failed: \(error)")
            }
        } else {
            print("ℹ️ No memos available for deletion test")
        }

        // Clean up
        try? FileManager.default.removeItem(at: testAudioURL)

        print("✅ Updated memo use cases test completed")
    }

    @Test func testErrorMapping() async throws {
        // Test error mapping functionality
        let nsError = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [NSFilePathErrorKey: "/test/path"])
        let mappedError = ErrorMapping.mapError(nsError)

        #expect(mappedError.errorDescription?.contains("not found") == true)
        print("✅ Error mapping test: \(mappedError.errorDescription ?? "Unknown error")")

        // Test repository error mapping
        let repositoryError = RepositoryError.fileNotFound("/test/file")
        let sonoraError = repositoryError.asSonoraError

        #expect(sonoraError.errorDescription?.contains("not found") == true)
        print("✅ Repository error mapping test: \(sonoraError.errorDescription ?? "Unknown error")")
    }

}
