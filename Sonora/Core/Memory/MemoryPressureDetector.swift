//
//  MemoryPressureDetector.swift
//  Sonora
//
//  Centralized memory pressure detection and adaptive resource management
//  Monitors system conditions and provides intelligent recommendations for resource optimization
//

import Foundation
import UIKit

/// Protocol defining memory pressure monitoring operations
@MainActor
protocol MemoryPressureDetectorProtocol: Sendable {
    var isUnderMemoryPressure: Bool { get }
    var currentMemoryMetrics: MemoryMetrics { get }
    var onMemoryPressureChanged: ((Bool) -> Void)? { get set }
    
    func startMonitoring()
    func stopMonitoring()
    func forceMemoryPressureCheck() -> Bool
    func getResourceRecommendations() -> ResourceRecommendations
}

/// Advanced memory pressure detection and system resource monitoring
@MainActor
final class MemoryPressureDetector: MemoryPressureDetectorProtocol, ObservableObject, @unchecked Sendable {
    
    // MARK: - Configuration
    
    private struct DetectionConfig {
        static let monitoringInterval: TimeInterval = 15.0 // Check every 15 seconds
        static let memoryPressureThreshold: Double = 150.0 // MB
        static let criticalMemoryThreshold: Double = 200.0 // MB
        static let lowStorageThreshold: Double = 1.0 // GB
        static let batteryLowThreshold: Float = 0.2 // 20%
        static let thermalWarningThreshold: Int = 1 // .nominal = 0, .fair = 1, .serious = 2, .critical = 3
    }
    
    // MARK: - Published Properties
    
    @Published var isUnderMemoryPressure = false
    @Published var currentMemoryMetrics = MemoryMetrics()
    
    // MARK: - Properties
    
    var onMemoryPressureChanged: ((Bool) -> Void)?
    
    private let logger = Logger.shared
    private var monitoringTimer: Task<Void, Never>?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    // MARK: - Initialization
    
    init() {
        logger.info("🧠 MemoryPressureDetector: Initialized")
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stopMonitoring()
            self?.logger.info("🧠 MemoryPressureDetector: Deinitialized")
        }
    }
    
    // MARK: - Public Interface
    
    /// Starts continuous memory pressure monitoring
    func startMonitoring() {
        guard monitoringTimer == nil else {
            logger.debug("🧠 MemoryPressureDetector: Already monitoring")
            return
        }
        
        // Setup system memory pressure source
        setupSystemMemoryPressureSource()
        
        // Start periodic monitoring
        monitoringTimer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performMemoryCheck()
                
                do {
                    try await Task.sleep(nanoseconds: UInt64(DetectionConfig.monitoringInterval * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
        
        logger.info("🧠 MemoryPressureDetector: Started monitoring with \(DetectionConfig.monitoringInterval)s interval")
    }
    
    /// Stops memory pressure monitoring
    func stopMonitoring() {
        monitoringTimer?.cancel()
        monitoringTimer = nil
        
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        
        logger.info("🧠 MemoryPressureDetector: Stopped monitoring")
    }
    
    /// Forces an immediate memory pressure check
    /// - Returns: Current memory pressure state
    @discardableResult
    func forceMemoryPressureCheck() -> Bool {
        Task {
            await performMemoryCheck()
        }
        return isUnderMemoryPressure
    }
    
    /// Returns resource optimization recommendations based on current conditions
    func getResourceRecommendations() -> ResourceRecommendations {
        let metrics = currentMemoryMetrics
        var recommendations = ResourceRecommendations()
        
        // Memory-based recommendations
        if metrics.memoryUsageMB > DetectionConfig.criticalMemoryThreshold {
            recommendations.shouldAggressivelyCleanup = true
            recommendations.shouldUnloadCaches = true
            recommendations.shouldReduceQuality = true
        } else if metrics.memoryUsageMB > DetectionConfig.memoryPressureThreshold {
            recommendations.shouldUnloadCaches = true
            recommendations.shouldReduceQuality = true
        }
        
        // Storage-based recommendations  
        if metrics.availableStorageGB < DetectionConfig.lowStorageThreshold {
            recommendations.shouldCompressData = true
            recommendations.shouldCleanupOldFiles = true
            recommendations.shouldReduceQuality = true
        }
        
        // Battery-based recommendations
        if metrics.batteryLevel >= 0 && metrics.batteryLevel < DetectionConfig.batteryLowThreshold {
            recommendations.shouldReduceQuality = true
            recommendations.shouldDisableBackgroundProcessing = true
        }
        
        // Thermal-based recommendations
        if metrics.thermalState.rawValue >= DetectionConfig.thermalWarningThreshold {
            recommendations.shouldThrottleOperations = true
            recommendations.shouldReduceQuality = true
            
            if metrics.thermalState == .critical {
                recommendations.shouldAggressivelyCleanup = true
                recommendations.shouldUnloadCaches = true
                recommendations.shouldDisableBackgroundProcessing = true
            }
        }
        
        // Overall system stress assessment
        recommendations.systemStressLevel = calculateSystemStressLevel(metrics)
        
        return recommendations
    }
    
    // MARK: - Private Implementation
    
    private func setupSystemMemoryPressureSource() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)
        
        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleSystemMemoryPressureEvent()
            }
        }
        
        memoryPressureSource?.resume()
    }
    
    private func handleSystemMemoryPressureEvent() async {
        guard let source = memoryPressureSource else { return }
        
        let eventMask = source.mask
        
        // System memory pressure events
        if eventMask.contains(.warning) {
            logger.warning("🧠 MemoryPressureDetector: System memory warning received")
            await updateMemoryPressure(true)
        } else if eventMask.contains(.critical) {
            logger.error("🧠 MemoryPressureDetector: System critical memory pressure received")
            await updateMemoryPressure(true)
        } else if eventMask.contains(.normal) {
            logger.info("🧠 MemoryPressureDetector: System memory pressure relieved")
        }
        
        // Always perform full check on system events
        await performMemoryCheck()
    }
    
    private func performMemoryCheck() async {
        let metrics = collectMemoryMetrics()
        currentMemoryMetrics = metrics
        
        // Determine memory pressure based on multiple factors
        let memoryPressure = metrics.memoryUsageMB > DetectionConfig.memoryPressureThreshold
        let thermalPressure = metrics.thermalState.rawValue >= 2 // .serious or .critical
        let storagePressure = metrics.availableStorageGB < DetectionConfig.lowStorageThreshold
        let batteryPressure = metrics.batteryLevel >= 0 && metrics.batteryLevel < DetectionConfig.batteryLowThreshold
        
        let newPressureState = memoryPressure || thermalPressure || storagePressure || batteryPressure
        
        if newPressureState != isUnderMemoryPressure {
            await updateMemoryPressure(newPressureState)
        }
        
        // Log significant changes
        if newPressureState {
            logger.debug("🧠 MemoryPressureDetector: Pressure factors - Memory: \(memoryPressure), Thermal: \(thermalPressure), Storage: \(storagePressure), Battery: \(batteryPressure)")
        }
    }
    
    private func updateMemoryPressure(_ underPressure: Bool) async {
        let previousState = isUnderMemoryPressure
        isUnderMemoryPressure = underPressure
        
        if previousState != underPressure {
            let stateDescription = underPressure ? "detected" : "relieved"
            logger.info("🧠 MemoryPressureDetector: Memory pressure \(stateDescription)")
            
            // Notify observers
            onMemoryPressureChanged?(underPressure)
            
            // Post system-wide notification
            NotificationCenter.default.post(
                name: .memoryPressureStateChanged,
                object: self,
                userInfo: ["isUnderPressure": underPressure, "metrics": currentMemoryMetrics]
            )
        }
    }
    
    private func collectMemoryMetrics() -> MemoryMetrics {
        var metrics = MemoryMetrics()
        
        // Memory usage
        metrics.memoryUsageMB = getCurrentMemoryUsage()
        
        // Battery information
        let device = UIDevice.current
        if !device.isBatteryMonitoringEnabled {
            device.isBatteryMonitoringEnabled = true
        }
        metrics.batteryLevel = device.batteryLevel
        metrics.batteryState = device.batteryState
        
        // Thermal state
        metrics.thermalState = ProcessInfo.processInfo.thermalState
        
        // Storage information
        metrics.availableStorageGB = getAvailableStorage()
        
        // CPU usage
        metrics.cpuUsage = getCPUUsage()
        
        // System uptime
        metrics.systemUptime = ProcessInfo.processInfo.systemUptime
        
        return metrics
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        
        return 0.0
    }
    
    private func getAvailableStorage() -> Double {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                return freeSpace.doubleValue / (1024.0 * 1024.0 * 1024.0) // Convert to GB
            }
        } catch {
            logger.warning("🧠 MemoryPressureDetector: Failed to get storage info", 
                          category: .system, 
                          error: error)
        }
        return 100.0 // Default assumption
    }
    
    private func getCPUUsage() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let total = Double(info.cpu_ticks.0 + info.cpu_ticks.1 + info.cpu_ticks.2 + info.cpu_ticks.3)
            let user = Double(info.cpu_ticks.0)
            let system = Double(info.cpu_ticks.1)
            return (user + system) / total * 100.0
        }
        
        return 0.0
    }
    
    private func calculateSystemStressLevel(_ metrics: MemoryMetrics) -> SystemStressLevel {
        var stressScore = 0
        
        // Memory stress
        if metrics.memoryUsageMB > DetectionConfig.criticalMemoryThreshold {
            stressScore += 3
        } else if metrics.memoryUsageMB > DetectionConfig.memoryPressureThreshold {
            stressScore += 2
        }
        
        // Thermal stress
        stressScore += metrics.thermalState.rawValue
        
        // Battery stress
        if metrics.batteryLevel >= 0 && metrics.batteryLevel < 0.1 {
            stressScore += 3
        } else if metrics.batteryLevel >= 0 && metrics.batteryLevel < DetectionConfig.batteryLowThreshold {
            stressScore += 1
        }
        
        // Storage stress
        if metrics.availableStorageGB < 0.5 {
            stressScore += 2
        } else if metrics.availableStorageGB < DetectionConfig.lowStorageThreshold {
            stressScore += 1
        }
        
        // CPU stress
        if metrics.cpuUsage > 80.0 {
            stressScore += 2
        } else if metrics.cpuUsage > 60.0 {
            stressScore += 1
        }
        
        // Convert score to level
        switch stressScore {
        case 0...2:
            return .low
        case 3...6:
            return .medium
        case 7...10:
            return .high
        default:
            return .critical
        }
    }
}

// MARK: - Memory Metrics

/// Comprehensive system memory and resource metrics
public struct MemoryMetrics: Sendable {
    var memoryUsageMB: Double = 0
    var availableStorageGB: Double = 0
    var batteryLevel: Float = -1 // -1 if unknown
    var batteryState: UIDevice.BatteryState = .unknown
    var thermalState: ProcessInfo.ThermalState = .nominal
    var cpuUsage: Double = 0
    var systemUptime: TimeInterval = 0
    
    /// Whether the device is in a low-resource state
    var isResourceConstrained: Bool {
        let lowMemory = memoryUsageMB > 150.0
        let lowBattery = batteryLevel >= 0 && batteryLevel < 0.2
        let lowStorage = availableStorageGB < 1.0
        let thermalStress = thermalState.rawValue >= 2
        
        return lowMemory || lowBattery || lowStorage || thermalStress
    }
    
    /// Overall system health score (0.0 to 1.0, where 1.0 is excellent)
    var systemHealthScore: Double {
        var score = 1.0
        
        // Memory impact (up to -0.3)
        if memoryUsageMB > 200 {
            score -= 0.3
        } else if memoryUsageMB > 150 {
            score -= 0.15
        }
        
        // Battery impact (up to -0.2)
        if batteryLevel >= 0 {
            if batteryLevel < 0.1 {
                score -= 0.2
            } else if batteryLevel < 0.2 {
                score -= 0.1
            }
        }
        
        // Storage impact (up to -0.2)
        if availableStorageGB < 0.5 {
            score -= 0.2
        } else if availableStorageGB < 1.0 {
            score -= 0.1
        }
        
        // Thermal impact (up to -0.3)
        score -= Double(thermalState.rawValue) * 0.1
        
        return max(0.0, score)
    }
}

// MARK: - Resource Recommendations

/// Intelligent recommendations for resource optimization
public struct ResourceRecommendations: Sendable {
    var shouldUnloadCaches = false
    var shouldAggressivelyCleanup = false
    var shouldReduceQuality = false
    var shouldCompressData = false
    var shouldCleanupOldFiles = false
    var shouldThrottleOperations = false
    var shouldDisableBackgroundProcessing = false
    var systemStressLevel: SystemStressLevel = .low
    
    /// Whether any optimization is recommended
    var hasRecommendations: Bool {
        return shouldUnloadCaches || shouldAggressivelyCleanup || shouldReduceQuality ||
               shouldCompressData || shouldCleanupOldFiles || shouldThrottleOperations ||
               shouldDisableBackgroundProcessing
    }
    
    /// Priority score for recommendations (higher = more urgent)
    var priorityScore: Int {
        var score = 0
        if shouldAggressivelyCleanup { score += 3 }
        if shouldUnloadCaches { score += 2 }
        if shouldDisableBackgroundProcessing { score += 2 }
        if shouldThrottleOperations { score += 2 }
        if shouldReduceQuality { score += 1 }
        if shouldCompressData { score += 1 }
        if shouldCleanupOldFiles { score += 1 }
        return score
    }
}

// MARK: - System Stress Level

/// Overall system stress assessment
public enum SystemStressLevel: Int, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "System resources are adequate"
        case .medium: return "Moderate resource pressure detected"
        case .high: return "High resource pressure - optimizations recommended"
        case .critical: return "Critical resource pressure - aggressive optimization required"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let memoryPressureStateChanged = Notification.Name("memoryPressureStateChanged")
}
