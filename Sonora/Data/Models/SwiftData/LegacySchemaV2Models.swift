import Foundation
import SwiftData

// Legacy snapshots for schema V2 that still include nextRetryAt on job models.
@Model
final class MemoModelV2 {
    var id: UUID

    var creationDate: Date
    var customTitle: String?
    var filename: String
    var audioFilePath: String
    var duration: TimeInterval?
    var shareableFileName: String?

    @Relationship(deleteRule: .cascade)
    var transcription: TranscriptionModelV2?

    @Relationship(deleteRule: .cascade)
    var analysisResults: [AnalysisResultModelV2] = []

    @Relationship(deleteRule: .cascade)
    var autoTitleJob: AutoTitleJobModelV2?

    @Relationship(deleteRule: .cascade)
    var autoDistillJob: AutoDistillJobModelV2?

    init(
        id: UUID = UUID(),
        creationDate: Date,
        customTitle: String? = nil,
        filename: String,
        audioFilePath: String,
        duration: TimeInterval? = nil,
        shareableFileName: String? = nil,
        transcription: TranscriptionModelV2? = nil,
        analysisResults: [AnalysisResultModelV2] = [],
        autoTitleJob: AutoTitleJobModelV2? = nil,
        autoDistillJob: AutoDistillJobModelV2? = nil
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
        self.autoDistillJob = autoDistillJob
    }
}

@Model
final class TranscriptionModelV2 {
    var id: UUID

    var status: String
    var language: String
    var fullTranscript: String
    var lastUpdated: Date
    var metadataData: Data?

    var memo: MemoModelV2?

    init(
        id: UUID = UUID(),
        status: String,
        language: String,
        fullTranscript: String,
        lastUpdated: Date,
        metadataData: Data? = nil,
        memo: MemoModelV2? = nil
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
final class AnalysisResultModelV2 {
    var id: UUID

    var mode: String
    var summary: String
    var keywords: [String]
    var sentimentScore: Double?
    var timestamp: Date
    var payloadData: Data?

    var memo: MemoModelV2?

    init(
        id: UUID = UUID(),
        mode: String,
        summary: String,
        keywords: [String] = [],
        sentimentScore: Double? = nil,
        timestamp: Date,
        payloadData: Data? = nil,
        memo: MemoModelV2? = nil
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
final class AutoTitleJobModelV2 {
    var id: UUID

    var memoId: UUID
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date
    var retryCount: Int
    var lastError: String?
    var nextRetryAt: Date?
    var failureReasonRaw: String?

    @Relationship(inverse: \MemoModelV2.autoTitleJob)
    var memo: MemoModelV2?

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
        memo: MemoModelV2? = nil
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

@Model
final class AutoDistillJobModelV2 {
    var id: UUID
    var memoId: UUID
    var statusRaw: String
    var modeRaw: String
    var createdAt: Date
    var updatedAt: Date
    var retryCount: Int
    var lastError: String?
    var nextRetryAt: Date?
    var failureReasonRaw: String?

    @Relationship(inverse: \MemoModelV2.autoDistillJob)
    var memo: MemoModelV2?

    init(
        id: UUID = UUID(),
        memoId: UUID,
        statusRaw: String,
        modeRaw: String,
        createdAt: Date,
        updatedAt: Date,
        retryCount: Int,
        lastError: String? = nil,
        nextRetryAt: Date? = nil,
        failureReasonRaw: String? = nil,
        memo: MemoModelV2? = nil
    ) {
        self.id = id
        self.memoId = memoId
        self.statusRaw = statusRaw
        self.modeRaw = modeRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.retryCount = retryCount
        self.lastError = lastError
        self.nextRetryAt = nextRetryAt
        self.failureReasonRaw = failureReasonRaw
        self.memo = memo
    }
}
