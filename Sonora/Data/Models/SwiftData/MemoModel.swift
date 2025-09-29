import Foundation
import SwiftData

@Model
final class MemoModel {
    // Explicitly assigned UUID, not auto-generated (SwiftData requires var)
    var id: UUID

    var creationDate: Date
    var customTitle: String?
    var filename: String
    var audioFilePath: String
    var duration: TimeInterval?
    var shareableFileName: String?

    // One-to-one relationship (cascade delete)
    @Relationship(deleteRule: .cascade)
    var transcription: TranscriptionModel?

    // One-to-many relationship (cascade delete)
    @Relationship(deleteRule: .cascade)
    var analysisResults: [AnalysisResultModel] = []

    @Relationship(deleteRule: .cascade)
    var autoTitleJob: AutoTitleJobModel?

    init(
        id: UUID = UUID(),
        creationDate: Date,
        customTitle: String? = nil,
        filename: String,
        audioFilePath: String,
        duration: TimeInterval? = nil,
        shareableFileName: String? = nil,
        transcription: TranscriptionModel? = nil,
        analysisResults: [AnalysisResultModel] = [],
        autoTitleJob: AutoTitleJobModel? = nil
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
