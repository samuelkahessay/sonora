import Foundation
import SwiftData

@Model
final class TranscriptionModel {
    // Explicitly assigned UUID (SwiftData requires var)
    var id: UUID

    var status: String
    var language: String
    var fullTranscript: String
    var lastUpdated: Date
    // Encoded TranscriptionMetadata for flexible/typed storage
    var metadataData: Data?

    // Inverse relationship to owning memo
    var memo: MemoModel?

    init(
        id: UUID = UUID(),
        status: String,
        language: String,
        fullTranscript: String,
        lastUpdated: Date,
        metadataData: Data? = nil,
        memo: MemoModel? = nil
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
