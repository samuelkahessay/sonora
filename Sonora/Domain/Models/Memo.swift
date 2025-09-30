import Foundation

/// Domain model representing a voice memo with enhanced business logic
public struct Memo: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let filename: String
    public let fileURL: URL
    public let creationDate: Date
    public let durationSeconds: TimeInterval?
    public let transcriptionStatus: DomainTranscriptionStatus
    public let analysisResults: [DomainAnalysisResult]
    public let customTitle: String?
    public let shareableFileName: String?
    public let autoTitleState: TitleGenerationState

    public init(
        id: UUID = UUID(),
        filename: String,
        fileURL: URL,
        creationDate: Date,
        durationSeconds: TimeInterval? = nil,
        transcriptionStatus: DomainTranscriptionStatus = .notStarted,
        analysisResults: [DomainAnalysisResult] = [],
        customTitle: String? = nil,
        shareableFileName: String? = nil,
        autoTitleState: TitleGenerationState = .idle
    ) {
        self.id = id
        self.filename = filename
        self.fileURL = fileURL
        self.creationDate = creationDate
        self.durationSeconds = durationSeconds
        self.transcriptionStatus = transcriptionStatus
        self.analysisResults = analysisResults
        self.customTitle = customTitle
        self.shareableFileName = shareableFileName
        self.autoTitleState = autoTitleState
    }

    // MARK: - Computed Properties

    /// Human-readable display name - uses custom title if available, otherwise date-based
    public var displayName: String {
        // Use custom title if available
        if let customTitle = customTitle, !customTitle.isEmpty {
            return customTitle
        }

        // Fallback to date and time format (e.g., "Jan 2, 2025 at 9:18 PM")
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }

    /// File extension without the dot
    public var fileExtension: String {
        fileURL.pathExtension
    }

    /// File size in bytes
    public var fileSizeBytes: Int64? {
        try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init)
    }

    /// Human-readable file size
    public var formattedFileSize: String {
        guard let bytes = fileSizeBytes else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Whether the memo has been successfully transcribed
    public var isTranscribed: Bool {
        transcriptionStatus.isCompleted
    }

    /// Whether transcription is currently in progress
    public var isTranscribing: Bool {
        transcriptionStatus.isInProgress
    }

    /// The transcribed text if available
    public var transcriptionText: String? {
        transcriptionStatus.text
    }

    /// Whether the memo has any analysis results
    public var hasAnalysisResults: Bool {
        !analysisResults.isEmpty
    }

    /// Number of completed analyses
    public var completedAnalysisCount: Int {
        analysisResults.filter { $0.isCompleted }.count
    }

    /// Filename for sharing - uses sanitized custom title or fallback
    public var preferredShareableFileName: String {
        if let shareableFileName = shareableFileName {
            return shareableFileName
        }

        // Fallback: generate from displayName
        return FileNameSanitizer.sanitize(displayName)
    }

    // MARK: - Business Logic Methods

    /// Creates a copy with updated transcription status
    public func withTranscriptionStatus(_ status: DomainTranscriptionStatus) -> Self {
        Self(
            id: id,
            filename: filename,
            fileURL: fileURL,
            creationDate: creationDate,
            durationSeconds: durationSeconds,
            transcriptionStatus: status,
            analysisResults: analysisResults,
            customTitle: customTitle,
            shareableFileName: shareableFileName,
            autoTitleState: autoTitleState
        )
    }

    /// Creates a copy with a custom title
    public func withCustomTitle(_ title: String?) -> Self {
        let newShareableFileName = title != nil ? FileNameSanitizer.sanitize(title!) : nil
        return Self(
            id: id,
            filename: filename,
            fileURL: fileURL,
            creationDate: creationDate,
            durationSeconds: durationSeconds,
            transcriptionStatus: transcriptionStatus,
            analysisResults: analysisResults,
            customTitle: title,
            shareableFileName: newShareableFileName,
            autoTitleState: autoTitleState
        )
    }

    /// Creates a copy with added analysis result
    public func withAnalysisResult(_ result: DomainAnalysisResult) -> Self {
        var updatedResults = analysisResults
        updatedResults.append(result)

        return Self(
            id: id,
            filename: filename,
            fileURL: fileURL,
            creationDate: creationDate,
            durationSeconds: durationSeconds,
            transcriptionStatus: transcriptionStatus,
            analysisResults: updatedResults,
            customTitle: customTitle,
            shareableFileName: shareableFileName,
            autoTitleState: autoTitleState
        )
    }

    /// Creates a copy with an updated auto-title state
    public func withAutoTitleState(_ state: TitleGenerationState) -> Self {
        Self(
            id: id,
            filename: filename,
            fileURL: fileURL,
            creationDate: creationDate,
            durationSeconds: durationSeconds,
            transcriptionStatus: transcriptionStatus,
            analysisResults: analysisResults,
            customTitle: customTitle,
            shareableFileName: shareableFileName,
            autoTitleState: state
        )
    }

    /// Gets analysis result by type
    public func analysisResult(ofType type: DomainAnalysisType) -> DomainAnalysisResult? {
        analysisResults.first { $0.type == type }
    }

    /// Checks if analysis of given type is completed
    public func hasCompletedAnalysis(ofType type: DomainAnalysisType) -> Bool {
        analysisResult(ofType: type)?.isCompleted ?? false
    }
}

// MARK: - Supporting Domain Types

/// Domain model for transcription status
public enum DomainTranscriptionStatus: Codable, Equatable, Hashable, Sendable {
    case notStarted
    case inProgress
    case completed(String)
    case failed(String)

    public var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    public var isInProgress: Bool {
        if case .inProgress = self { return true }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    public var isNotStarted: Bool {
        if case .notStarted = self { return true }
        return false
    }

    public var text: String? {
        if case .completed(let text) = self { return text }
        return nil
    }

    public var errorMessage: String? {
        if case .failed(let error) = self { return error }
        return nil
    }

    public var statusDescription: String {
        switch self {
        case .notStarted:
            return "Not transcribed"
        case .inProgress:
            return "Transcribing..."
        case .completed:
            return "Transcribed"
        case .failed:
            return "Transcription failed"
        }
    }
}

/// Domain model for analysis types
public enum DomainAnalysisType: String, CaseIterable, Codable, Hashable, Sendable {
    case distill
    case summary
    case themes
    case actionItems = "action_items"
    case keyPoints = "key_points"

    public var displayName: String {
        switch self {
        case .distill: return "Distill"
        case .summary: return "Summary"
        case .themes: return "Themes"
        case .actionItems: return "Action Items"
        case .keyPoints: return "Key Points"
        }
    }

    public var iconName: String {
        switch self {
        case .distill: return "sparkles"
        case .summary: return "text.quote"
        case .themes: return "tag.circle"
        case .actionItems: return "checkmark.circle.fill"
        case .keyPoints: return "list.bullet.circle"
        }
    }
}
