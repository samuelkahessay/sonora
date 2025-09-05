import Foundation
import SwiftData

@Model
final class AnalysisResultModel {
    // Explicitly assigned UUID (SwiftData requires var)
    var id: UUID

    var mode: String
    var summary: String
    var keywords: [String]
    var sentimentScore: Double?
    var timestamp: Date
    // Generic payload for the encoded AnalyzeEnvelope<T>
    var payloadData: Data?

    // Inverse relationship (many-to-one)
    var memo: MemoModel?

    init(
        id: UUID = UUID(),
        mode: String,
        summary: String,
        keywords: [String] = [],
        sentimentScore: Double? = nil,
        timestamp: Date,
        payloadData: Data? = nil,
        memo: MemoModel? = nil
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
