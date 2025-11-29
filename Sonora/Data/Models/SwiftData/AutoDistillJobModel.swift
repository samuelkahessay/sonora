import Foundation
import SwiftData

@Model
final class AutoDistillJobModel {
    var id: UUID
    var memoId: UUID
    var statusRaw: String
    var modeRaw: String
    var createdAt: Date
    var updatedAt: Date
    var retryCount: Int
    var lastError: String?
    var failureReasonRaw: String?

    @Relationship(inverse: \MemoModel.autoDistillJob)
    var memo: MemoModel?

    init(
        id: UUID = UUID(),
        memoId: UUID,
        statusRaw: String,
        modeRaw: String,
        createdAt: Date,
        updatedAt: Date,
        retryCount: Int,
        lastError: String? = nil,
        failureReasonRaw: String? = nil,
        memo: MemoModel? = nil
    ) {
        self.id = id
        self.memoId = memoId
        self.statusRaw = statusRaw
        self.modeRaw = modeRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.retryCount = retryCount
        self.lastError = lastError
        self.failureReasonRaw = failureReasonRaw
        self.memo = memo
    }
}
