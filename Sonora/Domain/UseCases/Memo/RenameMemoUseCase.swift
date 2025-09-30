//
//  RenameMemoUseCase.swift
//  Sonora
//
//  Use case for renaming memos with validation
//

import Foundation

// MARK: - Protocol

/// Protocol for renaming memos
protocol RenameMemoUseCaseProtocol {
    /// Rename a memo with the given title
    /// - Parameters:
    ///   - memo: The memo to rename
    ///   - newTitle: The new title for the memo
    /// - Throws: Error if rename fails or title is invalid
    @MainActor
    func execute(memo: Memo, newTitle: String) async throws
}

// MARK: - Implementation

/// Use case for renaming memos with proper validation
final class RenameMemoUseCase: RenameMemoUseCaseProtocol {

    // MARK: - Dependencies

    private let memoRepository: any MemoRepository

    // MARK: - Initialization

    init(
        memoRepository: any MemoRepository
    ) {
        self.memoRepository = memoRepository
    }

    // MARK: - Public Methods

    @MainActor
    func execute(memo: Memo, newTitle: String) async throws {
        print("📝 RenameMemoUseCase: Renaming memo \(memo.id) to '\(newTitle)'")

        // Validate input
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // Don't allow empty titles
        guard !trimmedTitle.isEmpty else {
            print("📝 RenameMemoUseCase: Attempted to rename with empty title")
            throw RenameMemoError.emptyTitle
        }

        // Don't rename if title hasn't changed
        if memo.customTitle == trimmedTitle {
            print("📝 RenameMemoUseCase: Title unchanged, skipping rename")
            return
        }

        // Rename the memo
        memoRepository.renameMemo(memo, newTitle: trimmedTitle)
        print("📝 RenameMemoUseCase: Successfully renamed memo to '\(trimmedTitle)'")
    }
}

// MARK: - Error Types

/// Errors that can occur during memo renaming
enum RenameMemoError: LocalizedError {
    case emptyTitle
    case renameFailed(Error)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Memo title cannot be empty"
        case .renameFailed(let error):
            return "Failed to rename memo: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyTitle:
            return "Please enter a valid title for the memo"
        case .renameFailed:
            return "Try renaming the memo again"
        }
    }
}
