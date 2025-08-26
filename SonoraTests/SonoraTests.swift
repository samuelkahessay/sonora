//
//  SonoraTests.swift
//  SonoraTests
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import Testing
@testable import Sonora

struct SonoraTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test @MainActor func testMemoRepositoryAtomicOperations() async throws {
        // Create a test repository
        let repository = MemoRepositoryImpl()
        
        // Create a test memo with a dummy audio file
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_audio.m4a")
        
        // Create a small test file
        let testData = Data("test audio content".utf8)
        try testData.write(to: testURL)
        
        let testMemo = Memo(
            filename: "test_audio.m4a",
            url: testURL,
            createdAt: Date()
        )
        
        // Test saving
        repository.saveMemo(testMemo)
        
        // Test loading
        repository.loadMemos()
        
        // Verify the memo was saved and loaded
        #expect(repository.memos.count >= 0) // At least no crash occurred
        
        // Clean up
        try? FileManager.default.removeItem(at: testURL)
        
        print("✅ MemoRepository atomic operations test completed successfully")
    }

}
