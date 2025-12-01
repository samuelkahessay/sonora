import Foundation
import SwiftData

// Legacy snapshots for schema V1 (before AutoDistillJob).
@Model
final class MemoModelV1 {
    var id: UUID

    var creationDate: Date
    var customTitle: String?
    var filename: String
    var audioFilePath: String
    var duration: TimeInterval?
    var shareableFileName: String?

    @Relationship(deleteRule: .cascade)
    var transcription: TranscriptionModelV1?

    @Relationship(deleteRule: .cascade)
    var analysisResults: [AnalysisResultModelV1] = []

    @Relationship(deleteRule: .cascade)
    var autoTitleJob: AutoTitleJobModelV1?

    init(
        id: UUID = UUID(),
        creationDate: Date,
        customTitle: String? = nil,
        filename: String,
        audioFilePath: String,
        duration: TimeInterval? = nil,
        shareableFileName: String? = nil,
        transcription: TranscriptionModelV1? = nil,
        analysisResults: [AnalysisResultModelV1] = [],
        autoTitleJob: AutoTitleJobModelV1? = nil
    ) {
        self.id = id
        self.creationDate = creationDate
        self.customTitle = customTitle
        self.filename = filename
        self.audioFilePath = audioFilePath
        self.duration = duration
        self.shareableFileName = shareableFileName
        self.transcription = transcription
        self.analysisResults = analysisResults
        self.autoTitleJob = autoTitleJob
    }
}

@Model
final class TranscriptionModelV1 {
    var id: UUID

    var status: String
    var language: String
    var fullTranscript: String
    var lastUpdated: Date
    var metadataData: Data?

    var memo: MemoModelV1?

    init(
        id: UUID = UUID(),
        status: String,
        language: String,
        fullTranscript: String,
        lastUpdated: Date,
        metadataData: Data? = nil,
        memo: MemoModelV1? = nil
    ) {
        self.id = id
        self.status = status
        self.language = language
        self.fullTranscript = fullTranscript
        self.lastUpdated = lastUpdated
        self.metadataData = metadataData
        self.memo = memo
    }
}

@Model
final class AnalysisResultModelV1 {
    var id: UUID

    var mode: String
    var summary: String
    var keywords: [String]
    var sentimentScore: Double?
    var timestamp: Date
    var payloadData: Data?

    var memo: MemoModelV1?

    init(
        id: UUID = UUID(),
        mode: String,
        summary: String,
        keywords: [String] = [],
        sentimentScore: Double? = nil,
        timestamp: Date,
        payloadData: Data? = nil,
        memo: MemoModelV1? = nil
    ) {
        self.id = id
        self.mode = mode
        self.summary = summary
        self.keywords = keywords
        self.sentimentScore = sentimentScore
        self.timestamp = timestamp
        self.payloadData = payloadData
        self.memo = memo
    }
}

@Model
final class AutoTitleJobModelV1 {
    var id: UUID

    var memoId: UUID
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date
    var retryCount: Int
    var lastError: String?
    var nextRetryAt: Date?
    var failureReasonRaw: String?

    @Relationship(inverse: \MemoModelV1.autoTitleJob)
    var memo: MemoModelV1?

    init(
        id: UUID = UUID(),
        memoId: UUID,
        statusRaw: String,
        createdAt: Date,
        updatedAt: Date,
        retryCount: Int,
        lastError: String? = nil,
        nextRetryAt: Date? = nil,
        failureReasonRaw: String? = nil,
        memo: MemoModelV1? = nil
    ) {
        self.id = id
        self.memoId = memoId
        self.statusRaw = statusRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.retryCount = retryCount
        self.lastError = lastError
        self.nextRetryAt = nextRetryAt
        self.failureReasonRaw = failureReasonRaw
        self.memo = memo
    }
}
