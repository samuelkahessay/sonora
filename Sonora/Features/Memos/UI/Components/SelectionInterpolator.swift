//
//  SelectionInterpolator.swift
//  Sonora
//
//  Handles fast drag movements and prevents skipping rows during selection
//  Implements gap-filling algorithms for smooth drag-to-select experience
//

import CoreGraphics
import Foundation

/// Interpolates selection ranges for fast drag movements to prevent skipping items
/// Uses line algorithms and velocity tracking to ensure smooth, continuous selection
struct SelectionInterpolator {
    
    // MARK: - Configuration
    
    private enum Config {
        /// Minimum velocity (points per second) to trigger interpolation
        static let minInterpolationVelocity: CGFloat = 200
        
        /// Maximum gap size (in indices) that we'll interpolate
        static let maxInterpolationGap: Int = 10
        
        /// Velocity threshold for fast drag detection
        static let fastDragVelocity: CGFloat = 500
        
        /// Maximum prediction distance based on velocity
        static let maxPredictionDistance: CGFloat = 100
    }
    
    // MARK: - Public Methods
    
    /// Calculate the selection range between two points, filling gaps for fast movements
    /// - Parameters:
    ///   - startIndex: Starting row index
    ///   - endIndex: Current row index
    ///   - velocity: Current drag velocity (points per second)
    ///   - rowHeight: Height of each row for calculation accuracy
    ///   - maxItems: Maximum number of items in the list
    /// - Returns: Range of indices that should be selected
    static func interpolateSelection(
        from startIndex: Int,
        to endIndex: Int,
        velocity: CGFloat = 0,
        rowHeight: CGFloat,
        maxItems: Int
    ) -> Range<Int> {
        
        // Basic bounds checking
        let clampedStart = max(0, min(startIndex, maxItems - 1))
        let clampedEnd = max(0, min(endIndex, maxItems - 1))
        
        let lower = min(clampedStart, clampedEnd)
        let upper = max(clampedStart, clampedEnd)
        let gap = upper - lower
        
        // For small gaps or slow movement, use simple range
        if gap <= 1 || velocity < Config.minInterpolationVelocity {
            return lower..<(upper + 1)
        }
        
        // For larger gaps with fast movement, use interpolation
        if gap <= Config.maxInterpolationGap {
            return interpolateRange(from: clampedStart, to: clampedEnd)
        }
        
        // For very large gaps (fast drag), use velocity-based prediction
        if velocity >= Config.fastDragVelocity {
            return predictiveSelection(
                from: clampedStart,
                to: clampedEnd,
                velocity: velocity,
                rowHeight: rowHeight,
                maxItems: maxItems
            )
        }
        
        // Fallback to simple range
        return lower..<(upper + 1)
    }
    
    /// Calculate smooth selection path between two drag points
    /// - Parameters:
    ///   - startPoint: Starting drag location
    ///   - endPoint: Current drag location
    ///   - rowHeight: Height of each row
    ///   - listOffset: Current scroll offset of the list
    ///   - maxItems: Maximum number of items
    /// - Returns: Array of row indices along the drag path
    static func interpolateDragPath(
        from startPoint: CGPoint,
        to endPoint: CGPoint,
        rowHeight: CGFloat,
        listOffset: CGFloat = 0,
        maxItems: Int
    ) -> [Int] {
        
        // Convert points to row indices
        let startIndex = pointToRowIndex(startPoint, rowHeight: rowHeight, listOffset: listOffset)
        let endIndex = pointToRowIndex(endPoint, rowHeight: rowHeight, listOffset: listOffset)
        
        // Use Bresenham-like algorithm for smooth line between points
        return bresenhamLine(from: startIndex, to: endIndex, maxItems: maxItems)
    }
    
    /// Detect if the user is performing a fast drag that might skip rows
    /// - Parameters:
    ///   - velocity: Current drag velocity
    ///   - gap: Gap size in row indices
    /// - Returns: True if this looks like a fast drag that needs interpolation
    static func isFastDrag(velocity: CGFloat, gap: Int) -> Bool {
        return velocity >= Config.minInterpolationVelocity && gap > 1
    }
    
    // MARK: - Private Methods
    
    /// Simple range interpolation for moderate gaps
    private static func interpolateRange(from start: Int, to end: Int) -> Range<Int> {
        let lower = min(start, end)
        let upper = max(start, end)
        return lower..<(upper + 1)
    }
    
    /// Velocity-based predictive selection for very fast drags
    private static func predictiveSelection(
        from start: Int,
        to end: Int,
        velocity: CGFloat,
        rowHeight: CGFloat,
        maxItems: Int
    ) -> Range<Int> {
        
        // Calculate prediction distance based on velocity
        let predictionFactor = min(velocity / Config.fastDragVelocity, 2.0)
        let predictionDistance = Config.maxPredictionDistance * predictionFactor
        let additionalRows = Int(predictionDistance / rowHeight)
        
        let lower = min(start, end)
        let upper = max(start, end)
        let direction = end > start ? 1 : -1
        
        // Extend selection in the direction of movement
        let predictedUpper = max(0, min(upper + (additionalRows * direction), maxItems - 1))
        let finalLower = min(lower, predictedUpper)
        let finalUpper = max(lower, predictedUpper)
        
        return finalLower..<(finalUpper + 1)
    }
    
    /// Convert a point coordinate to a row index
    private static func pointToRowIndex(
        _ point: CGPoint,
        rowHeight: CGFloat,
        listOffset: CGFloat
    ) -> Int {
        let adjustedY = point.y + listOffset - 8 // Account for safe area inset
        return max(0, Int(adjustedY / rowHeight))
    }
    
    /// Bresenham-like algorithm for drawing a line between two indices
    private static func bresenhamLine(from start: Int, to end: Int, maxItems: Int) -> [Int] {
        var result: [Int] = []
        
        let startIndex = max(0, min(start, maxItems - 1))
        let endIndex = max(0, min(end, maxItems - 1))
        
        if startIndex == endIndex {
            return [startIndex]
        }
        
        let distance = abs(endIndex - startIndex)
        let direction = endIndex > startIndex ? 1 : -1
        
        // Generate all indices between start and end
        for i in 0...distance {
            let currentIndex = startIndex + (i * direction)
            if currentIndex >= 0 && currentIndex < maxItems {
                result.append(currentIndex)
            }
        }
        
        return result
    }
}

// MARK: - Velocity Tracking Helper

/// Helper struct for tracking drag velocity over time
struct DragVelocityTracker {
    
    private var positions: [(time: Date, point: CGPoint)] = []
    private let maxHistory = 5
    
    /// Add a new position sample
    mutating func addSample(point: CGPoint, time: Date = Date()) {
        positions.append((time: time, point: point))
        
        // Keep history manageable
        if positions.count > maxHistory {
            positions.removeFirst()
        }
    }
    
    /// Calculate current velocity in points per second
    var currentVelocity: CGFloat {
        guard positions.count >= 2 else { return 0 }
        
        let recent = positions.suffix(2)
        let deltaY = recent.last!.point.y - recent.first!.point.y
        let deltaTime = recent.last!.time.timeIntervalSince(recent.first!.time)
        
        guard deltaTime > 0 else { return 0 }
        
        return abs(deltaY / deltaTime)
    }
    
    /// Get velocity vector (with direction)
    var velocityVector: CGPoint {
        guard positions.count >= 2 else { return .zero }
        
        let recent = positions.suffix(2)
        let delta = CGPoint(
            x: recent.last!.point.x - recent.first!.point.x,
            y: recent.last!.point.y - recent.first!.point.y
        )
        let deltaTime = recent.last!.time.timeIntervalSince(recent.first!.time)
        
        guard deltaTime > 0 else { return .zero }
        
        return CGPoint(
            x: delta.x / deltaTime,
            y: delta.y / deltaTime
        )
    }
    
    /// Reset velocity tracking
    mutating func reset() {
        positions.removeAll()
    }
}

// MARK: - Debug Extensions

#if DEBUG
extension SelectionInterpolator {
    
    /// Test interpolation with various parameters
    static func testInterpolation() -> String {
        var results: [String] = []
        
        // Test basic range
        let range1 = interpolateSelection(from: 0, to: 5, velocity: 0, rowHeight: 60, maxItems: 100)
        results.append("Basic range (0-5): \(range1)")
        
        // Test fast drag
        let range2 = interpolateSelection(from: 0, to: 10, velocity: 600, rowHeight: 60, maxItems: 100)
        results.append("Fast drag (0-10, v=600): \(range2)")
        
        // Test boundary conditions
        let range3 = interpolateSelection(from: 95, to: 105, velocity: 300, rowHeight: 60, maxItems: 100)
        results.append("Boundary test (95-105, max=100): \(range3)")
        
        // Test path interpolation
        let path = interpolateDragPath(
            from: CGPoint(x: 0, y: 60),
            to: CGPoint(x: 0, y: 300),
            rowHeight: 60,
            maxItems: 10
        )
        results.append("Drag path (60-300, row=60): \(path)")
        
        return results.joined(separator: "\n")
    }
}
#endif