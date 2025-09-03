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

/// Performance-optimized coordinator for Apple Voice Memos style drag-to-select
/// Handles gesture conflicts with List scrolling and provides smooth selection updates
@MainActor
final class DragSelectionCoordinator: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isDragSelecting: Bool = false
    @Published var currentIntent: DragIntent = .undetermined
    
    // MARK: - Internal State
    
    private var dragStartLocation: CGPoint = .zero
    private var lastUpdateTime: Date = .distantPast
    private var dragVelocity: CGPoint = .zero
    private var lastDragLocation: CGPoint = .zero
    private var gestureHistory: [CGPoint] = []
    
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
        
        // Clear selection intent if horizontal movement dominates in edit mode
        if isEditMode && horizontalDistance > Config.horizontalThreshold && 
           horizontalDistance > verticalDistance * 0.7 {
            return .selecting
        }
        
        // Clear scroll intent if vertical movement dominates and not in edit mode
        if !isEditMode && verticalDistance > Config.verticalScrollThreshold &&
           verticalDistance > horizontalDistance * 1.5 {
            return .scrolling
        }
        
        // In edit mode, bias toward selection
        if isEditMode {
            return .selecting
        }
        
        // Default to scrolling for vertical lists
        return verticalDistance > horizontalDistance ? .scrolling : .selecting
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
    
    /// Initialize drag selection mode
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
        viewModel.dragStartIndex = startIndex
        
        // Play initial haptic
        HapticManager.shared.playSelection()
        
        // Announce for accessibility
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
        
        // Handle fast drag interpolation
        let interpolatedRange = interpolateSelection(
            from: viewModel.dragCurrentIndex ?? viewModel.dragStartIndex ?? 0,
            to: clampedIndex,
            maxItems: viewModel.memos.count
        )
        
        // Update selection with interpolated range
        updateSelectionRange(
            range: interpolatedRange,
            viewModel: viewModel
        )
        
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
        
        // Play completion haptic
        HapticManager.shared.playSelection()
        
        // Announce completion for accessibility
        announceSelectionComplete(count: viewModel.selectedCount)
    }
    
    // MARK: - Helper Methods
    
    /// Calculate row index for a given point, accounting for list offset
    private func calculateRowIndex(for point: CGPoint, rowHeight: CGFloat) -> Int {
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
    
    /// Interpolate selection range for fast drags to prevent skipping rows
    private func interpolateSelection(from startIndex: Int, to endIndex: Int, maxItems: Int) -> Range<Int> {
        let clampedStart = max(0, min(startIndex, maxItems - 1))
        let clampedEnd = max(0, min(endIndex, maxItems - 1))
        
        let lower = min(clampedStart, clampedEnd)
        let upper = max(clampedStart, clampedEnd)
        
        return lower..<(upper + 1)
    }
    
    /// Update selection range in view model with haptic feedback
    private func updateSelectionRange(range: Range<Int>, viewModel: MemoListViewModel) {
        let memosToSelect = Array(viewModel.memos[range])
        let previousCount = viewModel.selectedCount
        
        // Update selection
        withAnimation(.easeOut(duration: 0.1)) {
            for memo in memosToSelect {
                viewModel.selectedMemoIds.insert(memo.id)
            }
        }
        
        // Provide haptic feedback if selection meaningfully changed
        if hapticDebouncer.shouldFireHaptic(newCount: viewModel.selectedCount) {
            HapticManager.shared.playSelection()
        }
        
        // Update accessibility announcement
        announceSelectionUpdate(count: viewModel.selectedCount)
    }
    
    /// Handle auto-scrolling when dragging near list edges
    private func handleEdgeScrolling(currentLocation: CGPoint, listBounds: CGRect) {
        let distanceFromTop = currentLocation.y - listBounds.minY
        let distanceFromBottom = listBounds.maxY - currentLocation.y
        
        // Auto-scroll logic would go here
        // This would require integration with ScrollView or List scrolling APIs
        // For now, we'll track the need but implementation depends on the ScrollView setup
        
        if distanceFromTop < Config.edgeScrollThreshold {
            // Should scroll up
            requestScrollDirection(.up)
        } else if distanceFromBottom < Config.edgeScrollThreshold {
            // Should scroll down
            requestScrollDirection(.down)
        }
    }
    
    enum ScrollDirection {
        case up, down
    }
    
    private func requestScrollDirection(_ direction: ScrollDirection) {
        // This would be implemented when integrating with ScrollViewReader
        // For now, we just track the intent
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
