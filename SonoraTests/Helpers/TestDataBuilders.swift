//
//  TestDataBuilders.swift
//  SonoraTests
//
//  Test data builders for creating test instances
//

@testable import Sonora
import Foundation

// MARK: - Memo Builder

struct MemoBuilder {
    static func make(
        id: UUID = UUID(),
        filename: String = "test.m4a",
        fileURL: URL? = nil,
        customTitle: String? = nil,
        durationSeconds: TimeInterval? = 60.0,
        creationDate: Date = Date(),
        transcriptionStatus: DomainTranscriptionStatus = .notStarted,
        analysisResults: [DomainAnalysisResult] = []
    ) -> Memo {
        let url = fileURL ?? URL(fileURLWithPath: "/tmp/\(filename)")
        return Memo(
            id: id,
            filename: filename,
            fileURL: url,
            creationDate: creationDate,
            durationSeconds: durationSeconds,
            transcriptionStatus: transcriptionStatus,
            analysisResults: analysisResults,
            customTitle: customTitle
        )
    }

    static func makeMany(count: Int, prefix: String = "Memo") -> [Memo] {
        return (0..<count).map { index in
            make(
                filename: "\(prefix)_\(index).m4a",
                customTitle: "\(prefix) \(index)",
                durationSeconds: Double(index + 1) * 10.0,
                creationDate: Date().addingTimeInterval(TimeInterval(-index * 3600))
            )
        }
    }
}

// MARK: - TranscriptionState Builder

struct TranscriptionStateBuilder {
    static func notStarted() -> TranscriptionState {
        .notStarted
    }

    static func inProgress() -> TranscriptionState {
        .inProgress
    }

    static func completed(_ text: String = "Test transcription text") -> TranscriptionState {
        .completed(text)
    }

    static func failed(_ message: String = "Test error") -> TranscriptionState {
        .failed(message)
    }
}

// MARK: - TranscriptionMetadata Builder

struct TranscriptionMetadataBuilder {
    static func make(
        memoId: UUID? = nil,
        state: String? = nil,
        text: String? = nil,
        originalText: String? = nil,
        detectedLanguage: String? = nil,
        qualityScore: Double? = nil,
        transcriptionService: TranscriptionServiceType? = nil,
        aiGenerated: Bool? = nil,
        moderationFlagged: Bool? = nil,
        moderationCategories: [String: Bool]? = nil
    ) -> TranscriptionMetadata {
        return TranscriptionMetadata(
            memoId: memoId,
            state: state,
            text: text,
            originalText: originalText,
            detectedLanguage: detectedLanguage,
            qualityScore: qualityScore,
            transcriptionService: transcriptionService,
            aiGenerated: aiGenerated,
            moderationFlagged: moderationFlagged,
            moderationCategories: moderationCategories
        )
    }
}

// MARK: - PlaybackProgress Builder

struct PlaybackProgressBuilder {
    static func make(
        memoId: UUID,
        currentTime: TimeInterval = 0.0,
        duration: TimeInterval = 60.0,
        isPlaying: Bool = false
    ) -> PlaybackProgress {
        return PlaybackProgress(
            memoId: memoId,
            currentTime: currentTime,
            duration: duration,
            isPlaying: isPlaying
        )
    }
}


// MARK: - Test Constants

enum TestConstants {
    static let defaultTimeout: TimeInterval = 5.0
    static let debounceDelay: UInt64 = 2_000_000_000 // 2s in nanoseconds (300ms debounce + ample time for all nested async operations)
    static let shortDelay: UInt64 = 100_000_000 // 100ms in nanoseconds
}
