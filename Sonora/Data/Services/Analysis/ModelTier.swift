import Foundation
import UIKit

/// Tiers for organizing AI models by performance and device requirements
enum ModelTier: String, CaseIterable, Identifiable {
    case fast = "fast"
    case balanced = "balanced"
    
    var id: String { rawValue }
    
    /// Display name for the tier
    var displayName: String {
        switch self {
        case .fast:
            return "Fast & Light"
        case .balanced:
            return "High Performance"
        }
    }
    
    /// Short description of the tier's characteristics
    var description: String {
        switch self {
        case .fast:
            return "Quick analysis with low memory usage"
        case .balanced:
            return "Best balance of speed and quality"
        }
    }
    
    /// Device requirement description
    var deviceRequirement: String {
        switch self {
        case .fast:
            return "iPhone 12 or newer"
        case .balanced:
            return "iPhone 14 or newer with 6GB+ RAM"
        }
    }
    
    /// Icon representing the tier
    var icon: String {
        switch self {
        case .fast:
            return "⚡"
        case .balanced:
            return "⚖️"
        }
    }
    
    /// System image name for the tier
    var systemImage: String {
        switch self {
        case .fast:
            return "bolt.fill"
        case .balanced:
            return "scale.3d"
        }
    }
    
    /// Minimum RAM required for this tier (in bytes)
    var minRAMRequired: UInt64 {
        switch self {
        case .fast:
            return 3_000_000_000  // 3GB
        case .balanced:
            return 6_000_000_000  // 6GB
        }
    }
    
    /// Check if the current device supports this tier
    var isDeviceCompatible: Bool {
        let deviceRAM = ProcessInfo.processInfo.physicalMemory
        return deviceRAM >= minRAMRequired
    }
    
    /// Priority order for recommendation (lower = higher priority)
    var recommendationPriority: Int {
        switch self {
        case .balanced:
            return 1  // Then balanced
        case .fast:
            return 2  // Fast as fallback
        }
    }
}

extension ModelTier {
    /// Get all tiers supported by the current device
    static var supportedTiers: [ModelTier] {
        return allCases.filter { $0.isDeviceCompatible }
    }
    
    /// Get the highest tier supported by the current device
    static var highestSupportedTier: ModelTier {
        return supportedTiers.min(by: { $0.recommendationPriority < $1.recommendationPriority }) ?? .fast
    }
    
    /// Get recommended tier for the current device
    static var recommendedTier: ModelTier {
        return highestSupportedTier
    }
}
