import Foundation
import Combine

/// Enhanced operation status system for comprehensive UI visibility
/// Provides real-time updates, progress tracking, and user-friendly status information

// MARK: - Operation Progress Tracking

/// Detailed progress information for long-running operations
public struct OperationProgress {
    public let percentage: Double        // 0.0 to 1.0
    public let currentStep: String      // Human-readable current operation
    public let estimatedTimeRemaining: TimeInterval?
    public let additionalInfo: [String: Any]?
    // New optional fields for step-aware progress
    public let totalSteps: Int?
    public let currentStepIndex: Int?
    
    public init(
        percentage: Double,
        currentStep: String,
        estimatedTimeRemaining: TimeInterval? = nil,
        additionalInfo: [String: Any]? = nil,
        totalSteps: Int? = nil,
        currentStepIndex: Int? = nil
    ) {
        self.percentage = max(0.0, min(1.0, percentage))
        self.currentStep = currentStep
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.additionalInfo = additionalInfo
        self.totalSteps = totalSteps
        self.currentStepIndex = currentStepIndex
    }
    
    /// Progress as percentage string (e.g., "75%")
    public var percentageString: String {
        return "\(Int(percentage * 100))%"
    }
    
    /// Estimated time remaining as human-readable string
    public var etaString: String? {
        guard let eta = estimatedTimeRemaining else { return nil }
        
        if eta < 60 {
            return "\(Int(eta))s remaining"
        } else if eta < 3600 {
            return "\(Int(eta / 60))m remaining"
        } else {
            return "\(Int(eta / 3600))h remaining"
        }
    }
}

// MARK: - Enhanced Operation Status

/// Extended operation status with detailed substates
public enum DetailedOperationStatus {
    // Pending substates
    case queued                          // In queue, waiting to start
    case waitingForResources            // Waiting for system resources
    case waitingForConflictResolution   // Blocked by conflicting operation
    
    // Active substates  
    case initializing                   // Starting up
    case processing(OperationProgress?) // Actively running with optional progress
    case finalizing                     // Completing/cleaning up
    
    // Terminal states
    case completed(Date)                // Successfully finished
    case failed(Error, Date)           // Failed with error
    case cancelled(Date)               // Cancelled by user or system
    
    /// Convert to basic OperationStatus for compatibility
    public var basicStatus: OperationStatus {
        switch self {
        case .queued, .waitingForResources, .waitingForConflictResolution:
            return .pending
        case .initializing, .processing, .finalizing:
            return .active
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .cancelled:
            return .cancelled
        }
    }
    
    /// Whether operation is still in progress
    public var isInProgress: Bool {
        return basicStatus.isInProgress
    }
    
    /// Human-readable status description
    public var displayName: String {
        switch self {
        case .queued:
            return "Queued"
        case .waitingForResources:
            return "Waiting for Resources"
        case .waitingForConflictResolution:
            return "Waiting (Conflict)"
        case .initializing:
            return "Starting"
        case .processing(let progress):
            if let progress = progress {
                return "\(progress.currentStep) (\(progress.percentageString))"
            }
            return "Processing"
        case .finalizing:
            return "Finishing"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    /// Icon name for UI display
    public var iconName: String {
        switch self {
        case .queued, .waitingForResources, .waitingForConflictResolution:
            return "clock.fill"
        case .initializing, .processing, .finalizing:
            return "gear"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .cancelled:
            return "minus.circle.fill"
        }
    }
    
    /// Color for UI display
    public var statusColor: StatusColor {
        switch self {
        case .queued, .waitingForResources, .waitingForConflictResolution:
            return .orange
        case .initializing, .processing, .finalizing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }
}

/// UI-friendly color enumeration
public enum StatusColor {
    case blue, green, orange, red, gray
}

// MARK: - DetailedOperationStatus Equatable & Hashable

extension DetailedOperationStatus: Equatable {
    public static func == (lhs: DetailedOperationStatus, rhs: DetailedOperationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.queued, .queued),
             (.waitingForResources, .waitingForResources),
             (.waitingForConflictResolution, .waitingForConflictResolution),
             (.initializing, .initializing),
             (.finalizing, .finalizing):
            return true
        case (.processing(let lhsProgress), .processing(let rhsProgress)):
            // Compare progress if both exist, or both are nil
            return (lhsProgress?.percentage == rhsProgress?.percentage &&
                    lhsProgress?.currentStep == rhsProgress?.currentStep)
        case (.completed(let lhsDate), .completed(let rhsDate)):
            return lhsDate == rhsDate
        case (.failed(_, let lhsDate), .failed(_, let rhsDate)):
            return lhsDate == rhsDate // Compare dates, not errors (errors don't conform to Equatable)
        case (.cancelled(let lhsDate), .cancelled(let rhsDate)):
            return lhsDate == rhsDate
        default:
            return false
        }
    }
}

extension DetailedOperationStatus: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .queued:
            hasher.combine("queued")
        case .waitingForResources:
            hasher.combine("waitingForResources")
        case .waitingForConflictResolution:
            hasher.combine("waitingForConflictResolution")
        case .initializing:
            hasher.combine("initializing")
        case .processing(let progress):
            hasher.combine("processing")
            hasher.combine(progress?.percentage)
            hasher.combine(progress?.currentStep)
        case .finalizing:
            hasher.combine("finalizing")
        case .completed(let date):
            hasher.combine("completed")
            hasher.combine(date)
        case .failed(_, let date):
            hasher.combine("failed")
            hasher.combine(date) // Hash date, not error
        case .cancelled(let date):
            hasher.combine("cancelled")
            hasher.combine(date)
        }
    }
}

// MARK: - Operation Notification System

/// Real-time operation status updates for UI
public struct OperationStatusUpdate {
    public let operationId: UUID
    public let memoId: UUID
    public let operationType: OperationType
    public let previousStatus: DetailedOperationStatus?
    public let currentStatus: DetailedOperationStatus
    public let timestamp: Date
    
    public init(
        operationId: UUID,
        memoId: UUID,
        operationType: OperationType,
        previousStatus: DetailedOperationStatus?,
        currentStatus: DetailedOperationStatus
    ) {
        self.operationId = operationId
        self.memoId = memoId
        self.operationType = operationType
        self.previousStatus = previousStatus
        self.currentStatus = currentStatus
        self.timestamp = Date()
    }
}

/// Protocol for receiving operation status updates
@MainActor
public protocol OperationStatusDelegate: AnyObject {
    func operationStatusDidUpdate(_ update: OperationStatusUpdate) async
    func operationDidComplete(_ operationId: UUID, memoId: UUID, operationType: OperationType) async
    func operationDidFail(_ operationId: UUID, memoId: UUID, operationType: OperationType, error: Error) async
}

// MARK: - Operation Grouping and Filtering

/// Grouping operations for UI presentation
public enum OperationGroup: CaseIterable {
    case recording
    case transcription  
    case analysis
    case all
    
    public var displayName: String {
        switch self {
        case .recording: return "Recording"
        case .transcription: return "Transcription"
        case .analysis: return "Analysis"
        case .all: return "All Operations"
        }
    }
    
    public var operationCategories: Set<OperationCategory> {
        switch self {
        case .recording: return [.recording]
        case .transcription: return [.transcription]
        case .analysis: return [.analysis]
        case .all: return Set(OperationCategory.allCases)
        }
    }
}

/// Filtering operations for UI presentation
public enum OperationFilter: CaseIterable {
    case active
    case pending
    case completed
    case failed
    case all
    
    public var displayName: String {
        switch self {
        case .active: return "Active"
        case .pending: return "Pending"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .all: return "All"
        }
    }
    
    public var statusFilter: Set<OperationStatus> {
        switch self {
        case .active: return [.active]
        case .pending: return [.pending]
        case .completed: return [.completed]
        case .failed: return [.failed]
        case .all: return Set(OperationStatus.allCases)
        }
    }
}

// MARK: - Operation Summary for UI

/// Summary of operation information for display
public struct OperationSummary {
    public let operation: Operation
    public let detailedStatus: DetailedOperationStatus
    public let userFriendlyDescription: String
    public let canBeCancelled: Bool
    public let estimatedCompletion: Date?
    
    public init(
        operation: Operation,
        detailedStatus: DetailedOperationStatus? = nil
    ) {
        self.operation = operation
        self.detailedStatus = detailedStatus ?? Self.mapToDetailedStatus(operation)
        self.userFriendlyDescription = Self.generateUserFriendlyDescription(operation)
        self.canBeCancelled = operation.status.isInProgress
        self.estimatedCompletion = Self.calculateEstimatedCompletion(operation)
    }
    
    private static func mapToDetailedStatus(_ operation: Operation) -> DetailedOperationStatus {
        switch operation.status {
        case .pending:
            return .queued
        case .active:
            return .processing(nil)
        case .completed:
            return .completed(operation.completedAt ?? Date())
        case .failed:
            let error = operation.error ?? NSError(domain: "OperationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            return .failed(error, operation.completedAt ?? Date())
        case .cancelled:
            return .cancelled(operation.completedAt ?? Date())
        }
    }
    
    private static func generateUserFriendlyDescription(_ operation: Operation) -> String {
        switch operation.type {
        case .recording:
            return "Recording audio"
        case .transcription:
            return "Converting speech to text"
        case .analysis(_, let analysisType):
            switch analysisType {
            case .distill:
                return "Generating comprehensive analysis"
            // Distill component operations
            case .distillSummary:
                return "Generating summary"
            case .distillActions:
                return "Extracting action items"
            case .distillThemes:
                return "Identifying themes"
            case .distillReflection:
                return "Creating reflection questions"
            case .themes:
                return "Analyzing themes"
            case .todos:
                return "Extracting action items"
            case .analysis:
                return "Performing detailed analysis"
            }
        }
    }
    
    private static func calculateEstimatedCompletion(_ operation: Operation) -> Date? {
        guard operation.status == .active else { return nil }
        
        // Simple estimation based on operation type and current duration
        let currentDuration = operation.executionDuration ?? 0
        let estimatedTotalDuration: TimeInterval
        
        switch operation.type.category {
        case .recording:
            return nil // Recording duration is user-controlled
        case .transcription:
            estimatedTotalDuration = 30.0 // Average transcription time
        case .analysis:
            estimatedTotalDuration = 15.0 // Average analysis time
        }
        
        let remainingTime = max(0, estimatedTotalDuration - currentDuration)
        return Date().addingTimeInterval(remainingTime)
    }
}

// MARK: - System Load Indicators

/// System performance metrics for operation coordination
public struct SystemOperationMetrics {
    public let totalOperations: Int
    public let activeOperations: Int
    public let queuedOperations: Int
    public let systemLoadPercentage: Double // 0.0 to 1.0
    public let maxConcurrentOperations: Int
    public let averageOperationDuration: TimeInterval?
    
    public var isSystemBusy: Bool {
        return systemLoadPercentage > 0.8
    }
    
    public var loadDescription: String {
        switch systemLoadPercentage {
        case 0.0..<0.3:
            return "Light Load"
        case 0.3..<0.7:
            return "Moderate Load"
        case 0.7..<0.9:
            return "Heavy Load"
        default:
            return "At Capacity"
        }
    }
    
    public var availableSlots: Int {
        return max(0, maxConcurrentOperations - activeOperations)
    }
    
    public var description: String {
        return """
        System Metrics:
        - Total Operations: \(totalOperations)
        - Active Operations: \(activeOperations)
        - Queued Operations: \(queuedOperations)
        - Available Slots: \(availableSlots)
        - System Load: \(loadDescription) (\(Int(systemLoadPercentage * 100))%)
        - Average Duration: \(averageOperationDuration.map { String(format: "%.1fs", $0) } ?? "N/A")
        """
    }
    
    public init(
        totalOperations: Int,
        activeOperations: Int,
        queuedOperations: Int,
        maxConcurrentOperations: Int,
        averageOperationDuration: TimeInterval?
    ) {
        self.totalOperations = totalOperations
        self.activeOperations = activeOperations
        self.queuedOperations = queuedOperations
        self.maxConcurrentOperations = maxConcurrentOperations
        self.systemLoadPercentage = Double(activeOperations) / Double(maxConcurrentOperations)
        self.averageOperationDuration = averageOperationDuration
    }
}
