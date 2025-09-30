import Foundation

/// Domain model representing the result of an analysis operation
public struct DomainAnalysisResult: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let type: DomainAnalysisType
    public let status: DomainAnalysisStatus
    public let content: DomainAnalysisContent?
    public let metadata: DomainAnalysisMetadata
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        type: DomainAnalysisType,
        status: DomainAnalysisStatus = .notStarted,
        content: DomainAnalysisContent? = nil,
        metadata: DomainAnalysisMetadata = DomainAnalysisMetadata(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.status = status
        self.content = content
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    /// Whether the analysis has completed successfully
    public var isCompleted: Bool {
        status.isCompleted
    }

    /// Whether the analysis is currently in progress
    public var isInProgress: Bool {
        status.isInProgress
    }

    /// Whether the analysis failed
    public var isFailed: Bool {
        status.isFailed
    }

    /// Human-readable status description
    public var statusDescription: String {
        status.description
    }

    /// Duration of the analysis operation
    public var duration: TimeInterval {
        updatedAt.timeIntervalSince(createdAt)
    }

    /// Human-readable duration
    public var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }

    // MARK: - Business Logic Methods

    /// Creates a copy with updated status
    public func withStatus(_ newStatus: DomainAnalysisStatus) -> Self {
        Self(
            id: id,
            type: type,
            status: newStatus,
            content: content,
            metadata: metadata,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }

    /// Creates a copy with updated content
    public func withContent(_ newContent: DomainAnalysisContent) -> Self {
        Self(
            id: id,
            type: type,
            status: .completed,
            content: newContent,
            metadata: metadata,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }

    /// Creates a copy with updated metadata
    public func withMetadata(_ newMetadata: DomainAnalysisMetadata) -> Self {
        Self(
            id: id,
            type: type,
            status: status,
            content: content,
            metadata: newMetadata,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

// MARK: - Supporting Domain Types

/// Status of an analysis operation
public enum DomainAnalysisStatus: Codable, Equatable, Hashable, Sendable {
    case notStarted
    case inProgress
    case completed
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

    public var errorMessage: String? {
        if case .failed(let error) = self { return error }
        return nil
    }

    public var description: String {
        switch self {
        case .notStarted:
            return "Not started"
        case .inProgress:
            return "In progress"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    public var iconName: String {
        switch self {
        case .notStarted:
            return "circle"
        case .inProgress:
            return "arrow.clockwise"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    public var iconColor: String {
        switch self {
        case .notStarted:
            return "secondary"
        case .inProgress:
            return "blue"
        case .completed:
            return "green"
        case .failed:
            return "red"
        }
    }
}

/// Content of an analysis result
public struct DomainAnalysisContent: Codable, Equatable, Hashable, Sendable {
    public let summary: String?
    public let keyPoints: [String]
    public let themes: [DomainTheme]
    public let actionItems: [DomainActionItem]
    public let sentiment: String?
    public let confidence: Double?

    public init(
        summary: String? = nil,
        keyPoints: [String] = [],
        themes: [DomainTheme] = [],
        actionItems: [DomainActionItem] = [],
        sentiment: String? = nil,
        confidence: Double? = nil
    ) {
        self.summary = summary
        self.keyPoints = keyPoints
        self.themes = themes
        self.actionItems = actionItems
        self.sentiment = sentiment
        self.confidence = confidence
    }

    /// Whether the content has meaningful data
    public var isEmpty: Bool {
        summary?.isEmpty != false &&
        keyPoints.isEmpty &&
        themes.isEmpty &&
        actionItems.isEmpty
    }

    /// Total number of content items
    public var itemCount: Int {
        (summary?.isEmpty == false ? 1 : 0) +
        keyPoints.count +
        themes.count +
        actionItems.count
    }

    /// Sentiment color for UI display
    public var sentimentColor: String {
        guard let sentiment = sentiment else { return "gray" }
        switch sentiment.lowercased() {
        case "positive": return "green"
        case "negative": return "red"
        case "mixed": return "orange"
        default: return "gray"
        }
    }
}

/// Theme identified in analysis
public struct DomainTheme: Codable, Equatable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let evidence: [String]
    public let confidence: Double?

    public init(
        id: UUID = UUID(),
        name: String,
        evidence: [String] = [],
        confidence: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.evidence = evidence
        self.confidence = confidence
    }

    /// Human-readable confidence level
    public var confidenceDescription: String {
        guard let confidence = confidence else { return "Unknown" }
        switch confidence {
        case 0.8...1.0: return "High"
        case 0.6..<0.8: return "Medium"
        case 0.0..<0.6: return "Low"
        default: return "Unknown"
        }
    }
}

/// Action item identified in analysis
public struct DomainActionItem: Codable, Equatable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let text: String
    public let priority: DomainPriority?
    public let dueDate: Date?
    public let isCompleted: Bool

    public init(
        id: UUID = UUID(),
        text: String,
        priority: DomainPriority? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.text = text
        self.priority = priority
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }

    /// Whether the action item is overdue
    public var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && dueDate < Date()
    }

    /// Human-readable due date
    public var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dueDate)
    }
}

/// Priority levels for action items
public enum DomainPriority: String, Codable, CaseIterable, Hashable, Sendable {
    case low
    case medium
    case high
    case urgent

    public var displayName: String {
        rawValue.capitalized
    }

    public var iconName: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "arrow.up.circle"
        case .urgent: return "exclamationmark.circle"
        }
    }

    public var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }
}

/// Metadata about an analysis operation
public struct DomainAnalysisMetadata: Codable, Equatable, Hashable, Sendable {
    public let modelUsed: String?
    public let tokensConsumed: Int?
    public let processingTimeMs: Int?
    public let version: String?
    public let parameters: [String: String]

    public init(
        modelUsed: String? = nil,
        tokensConsumed: Int? = nil,
        processingTimeMs: Int? = nil,
        version: String? = nil,
        parameters: [String: String] = [:]
    ) {
        self.modelUsed = modelUsed
        self.tokensConsumed = tokensConsumed
        self.processingTimeMs = processingTimeMs
        self.version = version
        self.parameters = parameters
    }

    /// Human-readable processing time
    public var formattedProcessingTime: String? {
        guard let ms = processingTimeMs else { return nil }
        if ms < 1_000 {
            return "\(ms)ms"
        } else {
            let seconds = Double(ms) / 1_000.0
            return String(format: "%.1fs", seconds)
        }
    }

    // MARK: - Hashable Implementation
    public func hash(into hasher: inout Hasher) {
        hasher.combine(modelUsed)
        hasher.combine(tokensConsumed)
        hasher.combine(processingTimeMs)
        hasher.combine(version)
        // Hash dictionary keys and values
        for (key, value) in parameters.sorted(by: { $0.key < $1.key }) {
            hasher.combine(key)
            hasher.combine(value)
        }
    }
}
