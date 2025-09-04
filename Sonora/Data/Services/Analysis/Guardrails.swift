//
//  Guardrails.swift
//  Sonora
//
//  Runtime safety guardrails for local AI inference
//  Prevents device overheating and memory pressure during Phi-3 operations
//

import Foundation
import os

/// Safety guardrails for local AI inference operations
/// Monitors thermal state, memory usage, and provides timeout mechanisms
enum Guardrails {
    
    // MARK: - Configuration
    
    private enum Limits {
        /// Maximum memory usage in MB before blocking inference
        static let memoryLimitMB: Double = 300
        
        /// Critical memory threshold in MB (emergency stop)
        static let criticalMemoryMB: Double = 500
        
        /// Default timeout for inference operations
        static let defaultTimeoutSeconds: TimeInterval = 45
        
        /// Memory check interval during long operations
        static let memoryCheckIntervalSeconds: TimeInterval = 5
    }
    
    // MARK: - Thermal State Monitoring
    
    /// Check current thermal state and throw error if unsafe for inference
    /// Phi-3 inference is CPU/memory intensive and can generate heat
    static func checkThermalState() throws {
        let state = ProcessInfo.processInfo.thermalState
        
        switch state {
        case .critical:
            Logger.shared.warning("Thermal state critical - blocking Phi-3 inference")
            throw GuardrailError.thermalCritical
            
        case .serious:
            Logger.shared.warning("Thermal state serious - blocking Phi-3 inference")
            throw GuardrailError.thermalSerious
            
        case .fair:
            Logger.shared.debug("Thermal state fair - allowing inference with monitoring")
            
        case .nominal:
            Logger.shared.debug("Thermal state nominal - optimal for inference")
            
        @unknown default:
            Logger.shared.warning("Unknown thermal state - proceeding with caution")
        }
    }
    
    // MARK: - Memory Pressure Monitoring
    
    /// Check current memory usage and throw error if too high
    /// Phi-3 models can use significant RAM during inference
    static func checkMemoryPressure() throws {
        let currentMemoryMB = getCurrentMemoryUsage()
        
        Logger.shared.debug("Current memory usage: \(String(format: "%.1f", currentMemoryMB))MB")
        
        if currentMemoryMB > Limits.criticalMemoryMB {
            Logger.shared.error("Critical memory usage: \(String(format: "%.1f", currentMemoryMB))MB")
            throw GuardrailError.memoryCritical(current: currentMemoryMB, limit: Limits.criticalMemoryMB)
        }
        
        if currentMemoryMB > Limits.memoryLimitMB {
            Logger.shared.warning("High memory usage: \(String(format: "%.1f", currentMemoryMB))MB")
            throw GuardrailError.memoryPressure(current: currentMemoryMB, limit: Limits.memoryLimitMB)
        }
    }
    
    /// Get current memory usage in MB
    static func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert bytes to MB
        }
        
        Logger.shared.error("Failed to get memory usage info")
        return 0
    }
    
    /// Get current memory pressure level
    static func getMemoryPressureLevel() -> MemoryPressureLevel {
        let memoryMB = getCurrentMemoryUsage()
        
        if memoryMB > Limits.criticalMemoryMB {
            return .critical
        } else if memoryMB > Limits.memoryLimitMB {
            return .high
        } else if memoryMB > Limits.memoryLimitMB * 0.7 {
            return .moderate
        } else {
            return .normal
        }
    }
    
    // MARK: - Timeout Operations
    
    /// Execute an operation with a timeout and periodic safety checks
    /// - Parameters:
    ///   - seconds: Timeout in seconds
    ///   - operation: The async operation to execute
    /// - Returns: Result of the operation
    /// - Throws: GuardrailError.timeout or the operation's error
    static func withTimeout<T>(
        _ seconds: TimeInterval = Limits.defaultTimeoutSeconds,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        
        try await withThrowingTaskGroup(of: T.self) { group in
            
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw GuardrailError.timeout(seconds: seconds)
            }
            
            // Add periodic safety monitoring task
            group.addTask {
                try await periodicSafetyCheck(intervalSeconds: Limits.memoryCheckIntervalSeconds)
                throw GuardrailError.safeguardTriggered("Periodic safety check failed")
            }
            
            // Wait for the first task to complete
            let result = try await group.next()!
            
            // Cancel all other tasks
            group.cancelAll()
            
            return result
        }
    }
    
    /// Perform periodic safety checks during long-running operations
    private static func periodicSafetyCheck(intervalSeconds: TimeInterval) async throws {
        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
            
            // Check if task was cancelled
            if Task.isCancelled {
                return
            }
            
            // Perform safety checks
            try checkThermalState()
            try checkMemoryPressure()
            
            Logger.shared.debug("Periodic safety check passed")
        }
    }
    
    // MARK: - System Health Assessment
    
    /// Get comprehensive system health status for inference decisions
    static func getSystemHealthStatus() -> SystemHealthStatus {
        let thermalState = ProcessInfo.processInfo.thermalState
        let memoryPressure = getMemoryPressureLevel()
        let memoryUsageMB = getCurrentMemoryUsage()
        
        let isHealthyForInference = thermalState == .nominal || thermalState == .fair
        let hasMemoryAvailable = memoryPressure == .normal || memoryPressure == .moderate
        
        return SystemHealthStatus(
            thermalState: thermalState,
            memoryPressureLevel: memoryPressure,
            memoryUsageMB: memoryUsageMB,
            isHealthyForInference: isHealthyForInference && hasMemoryAvailable,
            recommendedAction: recommendAction(thermal: thermalState, memory: memoryPressure)
        )
    }
    
    /// Get recommended action based on system state
    private static func recommendAction(
        thermal: ProcessInfo.ThermalState,
        memory: MemoryPressureLevel
    ) -> RecommendedAction {
        
        if thermal == .critical || memory == .critical {
            return .blockInference
        }
        
        if thermal == .serious || memory == .high {
            return .deferInference
        }
        
        if thermal == .fair || memory == .moderate {
            return .proceedWithMonitoring
        }
        
        return .proceedNormally
    }
}

// MARK: - Supporting Types

enum MemoryPressureLevel {
    case normal
    case moderate
    case high
    case critical
    
    var description: String {
        switch self {
        case .normal: return "Normal"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

enum RecommendedAction {
    case proceedNormally
    case proceedWithMonitoring
    case deferInference
    case blockInference
    
    var description: String {
        switch self {
        case .proceedNormally: return "Proceed normally"
        case .proceedWithMonitoring: return "Proceed with monitoring"
        case .deferInference: return "Defer inference"
        case .blockInference: return "Block inference"
        }
    }
}

struct SystemHealthStatus {
    let thermalState: ProcessInfo.ThermalState
    let memoryPressureLevel: MemoryPressureLevel
    let memoryUsageMB: Double
    let isHealthyForInference: Bool
    let recommendedAction: RecommendedAction
    
    var description: String {
        return """
        System Health Status:
        - Thermal: \(thermalStateDescription)
        - Memory: \(memoryPressureLevel.description) (\(String(format: "%.1f", memoryUsageMB))MB)
        - Healthy for inference: \(isHealthyForInference)
        - Recommended action: \(recommendedAction.description)
        """
    }
    
    private var thermalStateDescription: String {
        switch thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Error Types

enum GuardrailError: LocalizedError {
    case thermalCritical
    case thermalSerious
    case memoryPressure(current: Double, limit: Double)
    case memoryCritical(current: Double, limit: Double)
    case timeout(seconds: TimeInterval)
    case safeguardTriggered(String)
    
    var errorDescription: String? {
        switch self {
        case .thermalCritical:
            return "Device thermal state is critical - inference blocked for safety"
        case .thermalSerious:
            return "Device thermal state is serious - inference blocked to prevent overheating"
        case .memoryPressure(let current, let limit):
            return "High memory usage (\(String(format: "%.1f", current))MB exceeds \(String(format: "%.1f", limit))MB limit)"
        case .memoryCritical(let current, let limit):
            return "Critical memory usage (\(String(format: "%.1f", current))MB exceeds \(String(format: "%.1f", limit))MB critical threshold)"
        case .timeout(let seconds):
            return "Operation timed out after \(String(format: "%.1f", seconds)) seconds"
        case .safeguardTriggered(let reason):
            return "Safety safeguard triggered: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .thermalCritical, .thermalSerious:
            return "Allow the device to cool down before retrying. Close other resource-intensive apps."
        case .memoryPressure, .memoryCritical:
            return "Close other apps to free up memory, or try again later when memory usage is lower."
        case .timeout:
            return "The operation took too long. Try with a shorter prompt or check device performance."
        case .safeguardTriggered:
            return "System safety check failed. Ensure the device is in good operating condition."
        }
    }
}

// MARK: - Debug Extensions

#if DEBUG
extension Guardrails {
    /// Force a memory pressure simulation for testing
    static func simulateMemoryPressure() throws {
        throw GuardrailError.memoryPressure(current: 350, limit: 300)
    }
    
    /// Get detailed debug information about system state
    static func getDebugInfo() -> String {
        let health = getSystemHealthStatus()
        return """
        Guardrails Debug Info:
        \(health.description)
        
        Memory Limits:
        - Warning threshold: \(Limits.memoryLimitMB)MB
        - Critical threshold: \(Limits.criticalMemoryMB)MB
        - Current usage: \(String(format: "%.1f", getCurrentMemoryUsage()))MB
        
        Timeout Settings:
        - Default timeout: \(Limits.defaultTimeoutSeconds)s
        - Memory check interval: \(Limits.memoryCheckIntervalSeconds)s
        """
    }
}
#endif