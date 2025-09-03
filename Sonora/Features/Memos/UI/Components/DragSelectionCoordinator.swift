//
//  DragSelectionCoordinator.swift
//  Sonora
//
//  Performance-optimized drag-to-select coordinator
//  Handles gesture conflicts, throttling, and smooth selection updates
//

import SwiftUI
import Combine

/// Gesture intent detection for handling scroll vs selection conflicts
enum DragIntent {
    case undetermined
    case scrolling
    case selecting
}

/// Selection behavior for the current drag gesture
private enum DragSelectionMode {
    case select
    case deselect
}

/// Performance-optimized coordinator for Apple Voice Memos style drag-to-select
/// Handles gesture conflicts with List scrolling and provides smooth selection updates
@MainActor
final class DragSelectionCoordinator: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isDragSelecting: Bool = false
    @Published var currentIntent: DragIntent = .undetermined
    /// Published edge scroll direction to integrate with ScrollViewReader
    @Published var edgeScrollDirection: ScrollDirection? = nil
    /// Optional index resolver that maps a point in list coordinates -> row index
    var resolveIndex: ((CGPoint) -> Int?)? = nil
    
    // MARK: - Internal State
    
    private var dragStartLocation: CGPoint = .zero
    private var lastUpdateTime: Date = .distantPast
    private var dragVelocity: CGPoint = .zero
    private var lastDragLocation: CGPoint = .zero
    private var gestureHistory: [CGPoint] = []
    private var visitedIndices: Set<Int> = []
    private var dragMode: DragSelectionMode? = nil
    
    // MARK: - Configuration Constants
    
    private enum Config {
        static let minDragDistance: CGFloat = 20
        static let horizontalThreshold: CGFloat = 10
        static let verticalScrollThreshold: CGFloat = 30
        static let updateInterval: TimeInterval = 0.016 // 60fps
        static let velocityHistoryLimit: Int = 5
        static let longPressDelay: TimeInterval = 0.3
        static let edgeScrollThreshold: CGFloat = 50
        static let maxVelocityMagnitude: CGFloat = 2000
    }
    
    private let hapticDebouncer = HapticDebouncer()
    
    // MARK: - Gesture Intent Detection
    
    /// Determines whether the drag gesture should trigger selection or scrolling
    /// Uses horizontal movement bias and edit mode state to resolve conflicts
    func determineDragIntent(
        dragValue: DragGesture.Value,
        isEditMode: Bool,
        listBounds: CGRect
    ) -> DragIntent {
        
        let translation = dragValue.translation
        let distance = hypot(translation.width, translation.height)
        
        // Not enough movement yet
        guard distance > Config.minDragDistance else {
            return .undetermined
        }
        
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)

        // In edit mode, the caller attaches the drag to a narrow leading lane.
        // In that case, we bias strongly toward selecting to avoid scroll conflicts.
        if isEditMode { return .selecting }

        // Otherwise prefer scrolling for vertical drag, selecting for horizontal.
        if verticalDistance > Config.verticalScrollThreshold &&
            verticalDistance > horizontalDistance * 1.5 {
            return .scrolling
        }
        return .selecting
    }
    
    // MARK: - Drag Handling
    
    /// Handle drag gesture changes with performance throttling and intent detection
    func handleDragChanged(
        value: DragGesture.Value,
        viewModel: MemoListViewModel,
        listBounds: CGRect,
        rowHeight: CGFloat
    ) {
        let now = Date()
        
        // Performance throttling - limit to 60fps
        guard now.timeIntervalSince(lastUpdateTime) >= Config.updateInterval else {
            return
        }
        lastUpdateTime = now
        
        // Determine intent if still undetermined
        if currentIntent == .undetermined {
            currentIntent = determineDragIntent(
                dragValue: value,
                isEditMode: viewModel.isEditMode,
                listBounds: listBounds
            )
            
            if currentIntent == .selecting {
                startDragSelection(at: value.startLocation, viewModel: viewModel, rowHeight: rowHeight)
            }
        }
        
        // Only process selection updates if we're in selection mode
        guard currentIntent == .selecting && viewModel.isEditMode else {
            return
        }
        
        updateDragSelection(
            currentLocation: value.location,
            viewModel: viewModel,
            listBounds: listBounds,
            rowHeight: rowHeight
        )
    }
    
    /// Initialize drag selection mode and determine select/deselect behavior
    private func startDragSelection(
        at location: CGPoint,
        viewModel: MemoListViewModel,
        rowHeight: CGFloat
    ) {
        dragStartLocation = location
        isDragSelecting = true
        gestureHistory = [location]

        // Calculate starting row index
        let startIndex = calculateRowIndex(for: location, rowHeight: rowHeight)
        let clampedStart = max(0, min(startIndex, viewModel.memos.count - 1))
        viewModel.dragStartIndex = clampedStart
        viewModel.dragCurrentIndex = clampedStart
        viewModel.isDragSelecting = true

        // Determine drag mode based on start row state
        let initiallySelected = viewModel.isIndexSelected(clampedStart)
        dragMode = initiallySelected ? .deselect : .select
        visitedIndices = [clampedStart]

        // Apply initial state change
        applySelection(at: clampedStart, in: viewModel)

        // Haptic and accessibility
        HapticManager.shared.playSelection()
        announceSelectionStart()
    }
    
    /// Update drag selection based on current finger position
    private func updateDragSelection(
        currentLocation: CGPoint,
        viewModel: MemoListViewModel,
        listBounds: CGRect,
        rowHeight: CGFloat
    ) {
        // Update velocity tracking
        updateVelocityTracking(currentLocation: currentLocation)
        
        // Calculate current row index
        let currentIndex = calculateRowIndex(for: currentLocation, rowHeight: rowHeight)
        
        // Clamp to valid range
        let clampedIndex = max(0, min(currentIndex, viewModel.memos.count - 1))
        
        // Visit each crossed row exactly once and apply current drag mode
        updateSelectionPath(to: clampedIndex, viewModel: viewModel)
        
        // Update current index
        viewModel.dragCurrentIndex = clampedIndex
        
        // Handle edge scrolling if near boundaries
        handleEdgeScrolling(currentLocation: currentLocation, listBounds: listBounds)
        
        lastDragLocation = currentLocation
    }
    
    /// Handle drag gesture end
    func handleDragEnded(viewModel: MemoListViewModel) {
        // Clean up state
        currentIntent = .undetermined
        isDragSelecting = false
        dragVelocity = .zero
        gestureHistory.removeAll()
        
        // Clean up view model state
        viewModel.isDragSelecting = false
        viewModel.dragStartIndex = nil
        viewModel.dragCurrentIndex = nil
        
        // Haptic and announcements handled by caller
    }
    
    // MARK: - Helper Methods
    
    /// Calculate row index for a given point, accounting for list offset
    private func calculateRowIndex(for point: CGPoint, rowHeight: CGFloat) -> Int {
        // Prefer a precise resolver when available (uses measured row frames)
        if let idx = resolveIndex?(point) {
            return idx
        }
        // Adjust for safe area inset (8pt from MemosView)
        let adjustedY = point.y - 8
        return max(0, Int(adjustedY / rowHeight))
    }
    
    /// Update velocity tracking for momentum and interpolation
    private func updateVelocityTracking(currentLocation: CGPoint) {
        gestureHistory.append(currentLocation)
        
        // Keep history manageable
        if gestureHistory.count > Config.velocityHistoryLimit {
            gestureHistory.removeFirst()
        }
        
        // Calculate velocity if we have enough history
        if gestureHistory.count >= 2 {
            let recent = gestureHistory.suffix(2)
            let deltaY = recent.last!.y - recent.first!.y
            let deltaTime = Config.updateInterval
            
            dragVelocity.y = min(Config.maxVelocityMagnitude, abs(deltaY / deltaTime))
        }
    }
    
    /// Visit the path between the last index and the provided one, applying the drag mode once per index
    private func updateSelectionPath(to newIndex: Int, viewModel: MemoListViewModel) {
        guard let _ = dragMode else { return }
        let lastIndex = viewModel.dragCurrentIndex ?? viewModel.dragStartIndex ?? newIndex
        if newIndex == lastIndex { return }
        let step = newIndex > lastIndex ? 1 : -1
        var idx = lastIndex + step
        while (step > 0 && idx <= newIndex) || (step < 0 && idx >= newIndex) {
            if !visitedIndices.contains(idx) {
                applySelection(at: idx, in: viewModel)
                visitedIndices.insert(idx)
                HapticManager.shared.playSelection()
            }
            idx += step
        }
        announceSelectionUpdate(count: viewModel.selectedCount)
    }

    /// Apply selection/deselection at a specific index according to current drag mode
    private func applySelection(at index: Int, in viewModel: MemoListViewModel) {
        guard let dragMode else { return }
        guard index >= 0 && index < viewModel.memos.count else { return }
        switch dragMode {
        case .select:
            viewModel.setSelection(forIndex: index, selected: true)
        case .deselect:
            viewModel.setSelection(forIndex: index, selected: false)
        }
    }
    
    /// Handle auto-scrolling when dragging near list edges
    private func handleEdgeScrolling(currentLocation: CGPoint, listBounds: CGRect) {
        let distanceFromTop = currentLocation.y - listBounds.minY
        let distanceFromBottom = listBounds.maxY - currentLocation.y
        
        // Publish desired direction for the view layer to act on
        if distanceFromTop < Config.edgeScrollThreshold {
            edgeScrollDirection = .up
        } else if distanceFromBottom < Config.edgeScrollThreshold {
            edgeScrollDirection = .down
        } else {
            edgeScrollDirection = nil
        }
    }
    
    enum ScrollDirection {
        case up, down
    }
    
    private func requestScrollDirection(_ direction: ScrollDirection) { }

    /// Advance selection one row in the given direction (used by auto-scroll)
    func advanceSelection(direction: ScrollDirection, viewModel: MemoListViewModel) -> Int? {
        let current = viewModel.dragCurrentIndex ?? viewModel.dragStartIndex ?? 0
        var next = current + (direction == .down ? 1 : -1)
        next = max(0, min(next, viewModel.memos.count - 1))
        if next == current { return current }
        if !visitedIndices.contains(next) {
            applySelection(at: next, in: viewModel)
            visitedIndices.insert(next)
            HapticManager.shared.playSelection()
        }
        viewModel.dragCurrentIndex = next
        return next
    }
}

// MARK: - Accessibility Support

extension DragSelectionCoordinator {
    
    private func announceSelectionStart() {
        if UIAccessibility.isVoiceOverRunning {
            let announcement = NSAttributedString(string: "Drag selection started")
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
    
    private func announceSelectionUpdate(count: Int) {
        // Only announce every 5 items to avoid overwhelming VoiceOver
        if UIAccessibility.isVoiceOverRunning && count % 5 == 0 {
            let announcement = NSAttributedString(string: "\(count) items selected")
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
    
    private func announceSelectionComplete(count: Int) {
        if UIAccessibility.isVoiceOverRunning {
            let announcement = NSAttributedString(string: "Selection complete. \(count) items selected")
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
}

// MARK: - Performance Monitoring (Debug)

#if DEBUG
extension DragSelectionCoordinator {
    private var frameRate: Double {
        1.0 / Config.updateInterval
    }
    
    func logPerformanceMetrics() {
        print("🎯 DragCoordinator Performance:")
        print("   - Target FPS: \(frameRate)")
        print("   - Gesture History: \(gestureHistory.count)")
        print("   - Current Velocity: \(dragVelocity.y)")
        print("   - Intent: \(currentIntent)")
    }
}
#endif
