import Foundation

/// Domain model representing a voice memo with enhanced business logic
public struct Memo: Identifiable, Equatable, Hashable {
    public let id: UUID
    public let filename: String
    public let fileURL: URL
    public let creationDate: Date
    public let transcriptionStatus: DomainTranscriptionStatus
    public let analysisResults: [DomainAnalysisResult]
    
    public init(
        id: UUID = UUID(),
        filename: String,
        fileURL: URL,
        creationDate: Date,
        transcriptionStatus: DomainTranscriptionStatus = .notStarted,
        analysisResults: [DomainAnalysisResult] = []
    ) {
        self.id = id
        self.filename = filename
        self.fileURL = fileURL
        self.creationDate = creationDate
        self.transcriptionStatus = transcriptionStatus
        self.analysisResults = analysisResults
    }
    
    // MARK: - Computed Properties
    
    /// Human-readable display name based on creation date
    public var displayName: String {
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
        try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init) ?? nil
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
    
    // MARK: - Business Logic Methods
    
    /// Creates a copy with updated transcription status
    public func withTranscriptionStatus(_ status: DomainTranscriptionStatus) -> Memo {
        Memo(
            id: id,
            filename: filename,
            fileURL: fileURL,
            creationDate: creationDate,
            transcriptionStatus: status,
            analysisResults: analysisResults
        )
    }
    
    /// Creates a copy with added analysis result
    public func withAnalysisResult(_ result: DomainAnalysisResult) -> Memo {
        var updatedResults = analysisResults
        updatedResults.append(result)
        
        return Memo(
            id: id,
            filename: filename,
            fileURL: fileURL,
            creationDate: creationDate,
            transcriptionStatus: transcriptionStatus,
            analysisResults: updatedResults
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
public enum DomainTranscriptionStatus: Codable, Equatable, Hashable {
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
public enum DomainAnalysisType: String, CaseIterable, Codable, Hashable {
    case summary = "summary"
    case themes = "themes"
    case actionItems = "action_items"
    case keyPoints = "key_points"
    
    public var displayName: String {
        switch self {
        case .summary: return "Summary"
        case .themes: return "Themes"
        case .actionItems: return "Action Items"
        case .keyPoints: return "Key Points"
        }
    }
    
    public var iconName: String {
        switch self {
        case .summary: return "text.quote"
        case .themes: return "tag.circle"
        case .actionItems: return "checkmark.circle.fill"
        case .keyPoints: return "list.bullet.circle"
        }
    }
}
