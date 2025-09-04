import UIKit

extension UIDevice {
    /// Get the device's model identifier (e.g., "iPhone16,1" for iPhone 15 Pro)
    /// Uses a safe conversion that does not assume null-termination.
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)

        // Safely build a String from the fixed-size CChar tuple without
        // assuming null-termination or contiguous memory layout.
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }
    
    /// Human-readable device name based on model identifier
    var readableModelName: String {
        let identifier = modelIdentifier
        
        switch identifier {
        // iPhone 15 Series
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        
        // iPhone 16 Series
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        
        // iPhone 14 Series
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        
        // iPhone 13 Series
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        
        // iPhone 12 Series
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        
        // Simulator
        case let identifier where identifier.hasPrefix("x86_64") || identifier.hasPrefix("arm64"):
            return "Simulator"
        
        default:
            return identifier
        }
    }
    
    /// Check if the device is a Pro model (has more RAM and processing power)
    var isProModel: Bool {
        let identifier = modelIdentifier
        return [
            "iPhone16,1", // iPhone 15 Pro
            "iPhone16,2", // iPhone 15 Pro Max
            "iPhone17,1", // iPhone 16 Pro
            "iPhone17,2", // iPhone 16 Pro Max
            "iPhone15,2", // iPhone 14 Pro
            "iPhone15,3", // iPhone 14 Pro Max
            "iPhone14,2", // iPhone 13 Pro
            "iPhone14,3", // iPhone 13 Pro Max
            "iPhone13,3", // iPhone 12 Pro
            "iPhone13,4", // iPhone 12 Pro Max
        ].contains(identifier)
    }
    
    /// Estimated RAM capacity based on device model
    var estimatedRAMCapacity: UInt64 {
        let identifier = modelIdentifier
        
        switch identifier {
        // 8GB RAM devices (iPhone 15 Pro+)
        case "iPhone16,1", "iPhone16,2", "iPhone17,1", "iPhone17,2":
            return 8 * 1024 * 1024 * 1024
        
        // 6GB RAM devices (iPhone 14 Pro, iPhone 13 Pro series)
        case "iPhone15,2", "iPhone15,3", "iPhone14,2", "iPhone14,3":
            return 6 * 1024 * 1024 * 1024
        
        // 4GB RAM devices (iPhone 12 Pro, iPhone 13-15 base models)
        case "iPhone13,3", "iPhone13,4", "iPhone14,5", "iPhone14,4", "iPhone14,7", "iPhone14,8", "iPhone15,4", "iPhone15,5", "iPhone17,3", "iPhone17,4":
            return 4 * 1024 * 1024 * 1024
        
        // 3GB RAM devices (iPhone 12 mini, iPhone 13 mini)
        case "iPhone13,1", "iPhone13,2":
            return 3 * 1024 * 1024 * 1024
        
        default:
            // Default to system reported memory for unknown devices
            return ProcessInfo.processInfo.physicalMemory
        }
    }
    
    /// Get the highest tier supported by this device
    var deviceTier: ModelTier {
        let ram = estimatedRAMCapacity
        if ram >= 6_000_000_000 { return .balanced } // 6GB+
        return .fast // 4GB or less
    }
    
    /// Get all tiers supported by this device
    var supportedTiers: [ModelTier] {
        let currentTier = deviceTier
        switch currentTier {
        case .balanced:
            return [.fast, .balanced]
        case .fast:
            return [.fast]
        }
    }
    
    /// Check if device supports a specific tier
    func supportsTier(_ tier: ModelTier) -> Bool {
        return supportedTiers.contains(tier)
    }
}
