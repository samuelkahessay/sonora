import Foundation

/// Types of operations that can be performed on memos
/// Used for conflict detection and resource coordination
public enum OperationType: Hashable, CustomStringConvertible, Sendable {
    case recording(memoId: UUID)
    case transcription(memoId: UUID)
    case analysis(memoId: UUID, analysisType: AnalysisMode)

    /// The memo ID this operation targets
    public var memoId: UUID {
        switch self {
        case .recording(let memoId), .transcription(let memoId), .analysis(let memoId, _):
            return memoId
        }
    }

    /// Operation category for conflict detection
    public var category: OperationCategory {
        switch self {
        case .recording: return .recording
        case .transcription: return .transcription
        case .analysis: return .analysis
        }
    }

    public var description: String {
        switch self {
        case .recording(let memoId):
            return "Recording(memo: \(memoId))"
        case .transcription(let memoId):
            return "Transcription(memo: \(memoId))"
        case .analysis(let memoId, let type):
            return "Analysis(memo: \(memoId), type: \(type.displayName))"
        }
    }
}

/// Broad categories of operations for conflict detection
public enum OperationCategory: String, CaseIterable, Sendable {
    case recording = "recording"
    case transcription = "transcription"
    case analysis = "analysis"

    /// Operations that cannot run simultaneously with this category
    public var conflictsWith: Set<OperationCategory> {
        switch self {
        case .recording:
            // Recording conflicts with transcription on same memo
            // (can't transcribe while still recording)
            return [.transcription]
        case .transcription:
            // Transcription conflicts with recording on same memo
            // (can't start transcription while recording is active)
            return [.recording]
        case .analysis:
            // Analysis can run concurrently with other operations
            // (analysis uses transcription results, doesn't conflict with audio operations)
            return []
        }
    }
}

/// Priority levels for operation scheduling
public enum OperationPriority: Int, Comparable, CaseIterable, Sendable {
    case low = 0        // Analysis operations
    case medium = 1     // Transcription operations
    case high = 2       // Recording operations (user-interactive)

    public static func < (lhs: OperationPriority, rhs: OperationPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Get priority for operation type
    public static func priority(for operationType: OperationType) -> OperationPriority {
        switch operationType.category {
        case .recording:
            return .high        // Recording is user-interactive, highest priority
        case .transcription:
            return .medium      // Transcription needed before analysis
        case .analysis:
            return .low         // Analysis can be deferred
        }
    }

    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

/// Current status of an operation
public enum OperationStatus: String, CaseIterable, Sendable {
    case pending = "pending"        // Queued but not started
    case active = "active"          // Currently running
    case completed = "completed"    // Successfully finished
    case failed = "failed"          // Failed with error
    case cancelled = "cancelled"    // Cancelled before completion

    /// Whether this status indicates the operation is still in progress
    public var isInProgress: Bool {
        switch self {
        case .pending, .active:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }

    /// Whether this status indicates the operation finished (regardless of success)
    public var isFinished: Bool {
        return !isInProgress
    }

    public var displayName: String {
        return rawValue.capitalized
    }
}

/// Complete operation information for tracking
public struct Operation: Hashable, CustomStringConvertible, Sendable {
    public let id: UUID
    public let type: OperationType
    public let priority: OperationPriority
    public let createdAt: Date
    public var status: OperationStatus
    public var startedAt: Date?
    public var completedAt: Date?
    public var errorDescription: String?
    public var progress: OperationProgress?

    public init(
        type: OperationType,
        priority: OperationPriority? = nil,
        status: OperationStatus = .pending
    ) {
        self.id = UUID()
        self.type = type
        self.priority = priority ?? OperationPriority.priority(for: type)
        self.createdAt = Date()
        self.status = status
        self.progress = nil
    }

    /// Duration of operation execution (if started)
    public var executionDuration: TimeInterval? {
        guard let startedAt = startedAt else { return nil }
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }

    /// Total time since creation
    public var totalDuration: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }

    public var description: String {
        return "Operation(id: \(id), type: \(type), status: \(status.displayName), priority: \(priority.displayName))"
    }

    // MARK: - Hashable Implementation
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Operation, rhs: Operation) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Conflict detection and resolution strategies
public struct OperationConflict: Sendable {
    public let conflictingOperation: Operation
    public let requestedOperation: OperationType
    public let resolutionStrategy: ConflictResolutionStrategy

    public enum ConflictResolutionStrategy: Sendable {
        case queue          // Queue the new operation until conflict resolves
        case cancel         // Cancel the new operation
        case replace        // Cancel existing operation and start new one
        case allow          // Allow both (no actual conflict)
    }

    /// Determine if two operations conflict on the same memo
    public static func detectConflict(
        existing: Operation,
        proposed: OperationType
    ) -> OperationConflict? {
        // Only check conflicts on the same memo
        guard existing.type.memoId == proposed.memoId else {
            return nil
        }

        // Only check conflicts for active operations
        guard existing.status.isInProgress else {
            return nil
        }

        // Check if operation categories conflict
        let existingCategory = existing.type.category
        let proposedCategory = proposed.category

        guard existingCategory.conflictsWith.contains(proposedCategory) else {
            return nil
        }

        // Determine resolution strategy based on priorities
        let existingPriority = existing.priority
        let proposedPriority = OperationPriority.priority(for: proposed)

        let strategy: ConflictResolutionStrategy
        if proposedPriority > existingPriority {
            // Higher priority operation should replace lower priority
            strategy = .replace
        } else {
            // Lower or equal priority should queue
            strategy = .queue
        }

        return OperationConflict(
            conflictingOperation: existing,
            requestedOperation: proposed,
            resolutionStrategy: strategy
        )
    }
}

/// Performance and diagnostic information
public struct OperationMetrics: Sendable {
    public let totalOperations: Int
    public let activeOperations: Int
    public let queuedOperations: Int
    public let completedOperations: Int
    public let failedOperations: Int
    public let averageExecutionTime: TimeInterval?
    public let operationsByType: [OperationCategory: Int]

    public var successRate: Double {
        guard totalOperations > 0 else { return 0.0 }
        return Double(completedOperations) / Double(totalOperations)
    }

    public var description: String {
        return """
        OperationMetrics:
        - Total: \(totalOperations)
        - Active: \(activeOperations)
        - Queued: \(queuedOperations)
        - Completed: \(completedOperations)
        - Failed: \(failedOperations)
        - Success Rate: \(String(format: "%.1f", successRate * 100))%
        - Average Execution: \(averageExecutionTime.map { String(format: "%.2fs", $0) } ?? "N/A")
        """
    }
}
