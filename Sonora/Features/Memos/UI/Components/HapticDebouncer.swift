//
//  HapticDebouncer.swift
//  Sonora
//
//  Intelligent haptic feedback debouncing for drag selection
//  Prevents overwhelming haptic feedback during fast or micro movements
//

import Foundation

/// Intelligent debouncer for haptic feedback during drag selection
/// Prevents overwhelming users with excessive haptic feedback while maintaining responsiveness
final class HapticDebouncer {
    
    // MARK: - Configuration
    
    private enum Config {
        /// Minimum time between haptic feedback events (100ms)
        static let minInterval: TimeInterval = 0.1
        
        /// Minimum change in selection count to trigger haptic
        static let minCountDelta: Int = 3
        
        /// Maximum haptic events per second (10 Hz)
        static let maxHapticsPerSecond: Double = 10.0
        
        /// Time window for velocity calculation
        static let velocityWindow: TimeInterval = 0.3
    }
    
    // MARK: - State Tracking
    
    private var lastFeedbackTime: Date = .distantPast
    private var lastSelectionCount: Int = 0
    private var hapticHistory: [(time: Date, count: Int)] = []
    
    // MARK: - Public Interface
    
    /// Determines whether haptic feedback should be triggered based on selection changes
    /// - Parameter newCount: Current number of selected items
    /// - Returns: True if haptic feedback should be played
    func shouldFireHaptic(newCount: Int) -> Bool {
        let now = Date()
        
        // Update history
        updateHapticHistory(at: now, count: newCount)
        
        // Check time-based throttling
        let timeSinceLastHaptic = now.timeIntervalSince(lastFeedbackTime)
        guard timeSinceLastHaptic >= Config.minInterval else {
            return false
        }
        
        // Check count-based threshold
        let countDelta = abs(newCount - lastSelectionCount)
        guard countDelta >= Config.minCountDelta else {
            return false
        }
        
        // Check velocity-based throttling (prevent haptic spam during very fast drags)
        guard !isHapticVelocityTooHigh(at: now) else {
            return false
        }
        
        // Check for meaningful selection direction change
        if shouldTriggerForDirectionChange(newCount: newCount, at: now) {
            updateLastFeedback(at: now, count: newCount)
            return true
        }
        
        // Check for significant selection milestone
        if shouldTriggerForMilestone(newCount: newCount) {
            updateLastFeedback(at: now, count: newCount)
            return true
        }
        
        return false
    }
    
    /// Reset the debouncer state (useful when starting a new drag gesture)
    func reset() {
        lastFeedbackTime = .distantPast
        lastSelectionCount = 0
        hapticHistory.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func updateHapticHistory(at time: Date, count: Int) {
        hapticHistory.append((time: time, count: count))
        
        // Remove old entries outside the velocity window
        let cutoffTime = time.addingTimeInterval(-Config.velocityWindow)
        hapticHistory.removeAll { $0.time < cutoffTime }
    }
    
    private func isHapticVelocityTooHigh(at time: Date) -> Bool {
        let recentHaptics = hapticHistory.filter { 
            time.timeIntervalSince($0.time) <= (1.0 / Config.maxHapticsPerSecond)
        }
        
        return recentHaptics.count >= Int(Config.maxHapticsPerSecond)
    }
    
    private func shouldTriggerForDirectionChange(newCount: Int, at time: Date) -> Bool {
        guard hapticHistory.count >= 3 else { return false }
        
        let recent = Array(hapticHistory.suffix(3))
        let trend1 = recent[1].count - recent[0].count
        let trend2 = recent[2].count - recent[1].count
        
        // Detect direction change (positive to negative or vice versa)
        if (trend1 > 0 && trend2 < 0) || (trend1 < 0 && trend2 > 0) {
            return abs(trend2) >= Config.minCountDelta
        }
        
        return false
    }
    
    private func shouldTriggerForMilestone(newCount: Int) -> Bool {
        // Trigger on selection milestones (every 10 items for large selections)
        if newCount >= 20 && newCount % 10 == 0 {
            return true
        }
        
        // Trigger on smaller milestones for smaller selections
        if newCount <= 20 && newCount % 5 == 0 {
            return true
        }
        
        return false
    }
    
    private func updateLastFeedback(at time: Date, count: Int) {
        lastFeedbackTime = time
        lastSelectionCount = count
    }
}

// MARK: - Debug Extensions

#if DEBUG
extension HapticDebouncer {
    
    /// Debug information about the current debouncer state
    var debugInfo: String {
        let timeSinceLastHaptic = Date().timeIntervalSince(lastFeedbackTime)
        let recentHapticCount = hapticHistory.filter { 
            Date().timeIntervalSince($0.time) <= Config.velocityWindow 
        }.count
        
        return """
        HapticDebouncer State:
        - Last haptic: \(String(format: "%.2f", timeSinceLastHaptic))s ago
        - Last count: \(lastSelectionCount)
        - Recent haptics: \(recentHapticCount) in \(Config.velocityWindow)s
        - History length: \(hapticHistory.count)
        """
    }
    
    /// Test the debouncer with a sequence of selection counts
    func testSequence(_ counts: [Int], interval: TimeInterval = 0.05) -> [Bool] {
        reset()
        var results: [Bool] = []
        var testTime = Date()
        
        for count in counts {
            let shouldFire = shouldFireHaptic(newCount: count)
            results.append(shouldFire)
            testTime = testTime.addingTimeInterval(interval)
        }
        
        return results
    }
}
#endif

// MARK: - Factory Methods

extension HapticDebouncer {
    
    /// Create a haptic debouncer optimized for memo selection
    /// - Returns: Configured haptic debouncer
    static func forMemoSelection() -> HapticDebouncer {
        return HapticDebouncer()
    }
    
    /// Create a more sensitive haptic debouncer for accessibility users
    /// - Returns: Configured haptic debouncer with increased sensitivity
    static func forAccessibility() -> HapticDebouncer {
        let debouncer = HapticDebouncer()
        // Could customize configuration for accessibility users
        // For now, same configuration but could be enhanced based on user testing
        return debouncer
    }
}