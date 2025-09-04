// Moved to Features/Operations/ViewModels
import Foundation
import Combine
import SwiftUI

/// ViewModel for system-wide operation monitoring and management
/// Provides comprehensive visibility into all operations across the app
@MainActor
final class OperationStatusViewModel: ObservableObject, OperationStatusDelegate {
    
    // MARK: - Dependencies
    private let operationCoordinator: any OperationCoordinatorProtocol
    private let logger: any LoggerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    
    // System Overview
    @Published var systemMetrics: SystemOperationMetrics?
    @Published var allOperations: [OperationSummary] = []
    
    // Filtering and Grouping
    @Published var selectedGroup: OperationGroup = .all
    @Published var selectedFilter: OperationFilter = .active
    @Published var filteredOperations: [OperationSummary] = []
    
    // Real-time Updates
    @Published var recentUpdates: [OperationStatusUpdate] = []
    @Published var isRefreshing: Bool = false
    
    // MARK: - Computed Properties
    
    var hasActiveOperations: Bool {
        systemMetrics?.activeOperations ?? 0 > 0
    }
    
    var systemLoadText: String {
        guard let metrics = systemMetrics else { return "Loading..." }
        return "\(metrics.activeOperations) of \(metrics.maxConcurrentOperations) slots used"
    }
    
    var systemLoadPercentage: Double {
        systemMetrics?.systemLoadPercentage ?? 0.0
    }
    
    var canCancelAllOperations: Bool {
        hasActiveOperations
    }
    
    // MARK: - Initialization
    
    init(
        operationCoordinator: any OperationCoordinatorProtocol,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.operationCoordinator = operationCoordinator
        self.logger = logger
        
        setupOperationMonitoring()
        setupStatusDelegate()
        
        // Initial load
        Task {
            await refreshData()
        }
        
        logger.debug("OperationStatusViewModel initialized", 
                    category: .system, 
                    context: LogContext())
    }
    
    // MARK: - Setup Methods
    
    private func setupOperationMonitoring() {
        // Refresh data every 2 seconds
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupStatusDelegate() {
        operationCoordinator.setStatusDelegate(self)
    }
    
    // MARK: - Data Management
    
    func refreshData() async {
        isRefreshing = true
        
        // Get system metrics
        systemMetrics = await operationCoordinator.getSystemMetrics()
        
        // Get all operations
        allOperations = await operationCoordinator.getOperationSummaries(
            group: .all,
            filter: .all,
            for: nil
        )
        
        // Apply current filters
        await applyFilters()
        
        isRefreshing = false
    }
    
    private func applyFilters() async {
        filteredOperations = await operationCoordinator.getOperationSummaries(
            group: selectedGroup,
            filter: selectedFilter,
            for: nil
        )
    }
    
    // MARK: - User Actions
    
    /// Update filter selection
    func updateFilter(_ newGroup: OperationGroup, _ newFilter: OperationFilter) {
        selectedGroup = newGroup
        selectedFilter = newFilter
        
        Task {
            await applyFilters()
        }
    }
    
    /// Cancel specific operation
    func cancelOperation(_ operationId: UUID) {
        Task {
            await operationCoordinator.cancelOperation(operationId)
            logger.info("User cancelled operation: \(operationId)", 
                       category: .system, 
                       context: LogContext())
            await refreshData()
        }
    }
    
    /// Cancel all operations of specific type
    func cancelOperations(ofType category: OperationCategory) {
        Task {
            let cancelledCount = await operationCoordinator.cancelOperations(ofType: category)
            logger.info("User cancelled \(cancelledCount) operations of type: \(category.rawValue)", 
                       category: .system, 
                       context: LogContext())
            await refreshData()
        }
    }
    
    /// Emergency stop - cancel all operations
    func cancelAllOperations() {
        Task {
            let cancelledCount = await operationCoordinator.cancelAllOperations()
            logger.warning("User triggered emergency stop: \(cancelledCount) operations cancelled", 
                          category: .system, 
                          context: LogContext(), 
                          error: nil)
            await refreshData()
        }
    }
    
    /// Force refresh data
    func forceRefresh() {
        Task {
            await refreshData()
        }
    }
    
    // MARK: - Operation Details
    
    func getOperationDetails(_ operationSummary: OperationSummary) -> String {
        let op = operationSummary.operation
        let status = operationSummary.detailedStatus
        
        var details = [String]()
        details.append("ID: \(op.id)")
        details.append("Type: \(op.type.description)")
        details.append("Status: \(status.displayName)")
        details.append("Priority: \(op.priority.displayName)")
        details.append("Created: \(formatDate(op.createdAt))")
        
        if let startTime = op.startedAt {
            details.append("Started: \(formatDate(startTime))")
            
            if let duration = op.executionDuration {
                details.append("Duration: \(formatDuration(duration))")
            }
        }
        
        if let estimatedCompletion = operationSummary.estimatedCompletion {
            details.append("ETA: \(formatDate(estimatedCompletion))")
        }
        
        if let error = op.errorDescription {
            details.append("Error: \(error)")
        }
        
        return details.joined(separator: "\n")
    }
    
    // MARK: - Formatting Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else if duration < 3600 {
            return String(format: "%.1fm", duration / 60)
        } else {
            return String(format: "%.1fh", duration / 3600)
        }
    }
    
    // MARK: - Debug and Export
    
    func getDebugInfo() async -> String {
        let debugInfo = await operationCoordinator.getDebugInfo()
        let metrics = systemMetrics?.description ?? "No metrics available"
        
        return """
        OperationStatusViewModel Debug Info:
        
        System Metrics:
        \(metrics)
        
        Coordinator Info:
        \(debugInfo)
        
        Filtered Operations: \(filteredOperations.count)
        Recent Updates: \(recentUpdates.count)
        """
    }
    
    func exportOperationLog() -> String {
        let header = """
        Sonora Operations Log
        Generated: \(Date())
        System Load: \(systemLoadText)
        
        """
        
        let operations = allOperations.map { summary in
            """
            [\(formatDate(summary.operation.createdAt))] \(summary.operation.type.description)
            Status: \(summary.detailedStatus.displayName)
            Duration: \(summary.operation.executionDuration.map(formatDuration) ?? "N/A")
            """
        }.joined(separator: "\n\n")
        
        return header + operations
    }
}

// MARK: - OperationStatusDelegate

extension OperationStatusViewModel {
    
    func operationStatusDidUpdate(_ update: OperationStatusUpdate) async {
        // Add to recent updates (keep last 20)
        recentUpdates.insert(update, at: 0)
        if recentUpdates.count > 20 {
            recentUpdates.removeLast()
        }
        
        // Trigger data refresh for real-time updates
        Task {
            await refreshData()
        }
    }
    
    func operationDidComplete(_ operationId: UUID, memoId: UUID, operationType: OperationType) async {
        logger.info("Operation completed: \(operationType.description)", 
                   category: .system, 
                   context: LogContext(additionalInfo: [
                       "operationId": operationId.uuidString,
                       "memoId": memoId.uuidString
                   ]))
    }
    
    func operationDidFail(_ operationId: UUID, memoId: UUID, operationType: OperationType, error: Error) async {
        logger.error("Operation failed: \(operationType.description)", 
                    category: .system, 
                    context: LogContext(additionalInfo: [
                        "operationId": operationId.uuidString,
                        "memoId": memoId.uuidString
                    ]), 
                    error: error)
    }
}

// MARK: - UI Helper Extensions

extension OperationStatusViewModel {
    
    /// Get color for operation status
    func statusColor(for summary: OperationSummary) -> Color {
        switch summary.detailedStatus.statusColor {
        case .blue: return .semantic(.info)
        case .green: return .semantic(.success)
        case .orange: return .semantic(.warning)
        case .red: return .semantic(.error)
        case .gray: return .semantic(.separator)
        }
    }
    
    /// Get SF Symbol icon for operation
    func iconName(for summary: OperationSummary) -> String {
        return summary.detailedStatus.iconName
    }
    
    /// Get formatted operation title for display
    func operationTitle(for summary: OperationSummary) -> String {
        return summary.userFriendlyDescription
    }
    
    /// Get formatted operation subtitle
    func operationSubtitle(for summary: OperationSummary) -> String {
        let status = summary.detailedStatus.displayName
        let duration = summary.operation.executionDuration.map { 
            "(\(formatDuration($0)))" 
        } ?? ""
        
        return "\(status) \(duration)".trimmingCharacters(in: .whitespaces)
    }
}
