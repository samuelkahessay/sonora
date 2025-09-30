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
    func forceMemoryPressureCheck() -> Bool
}

/// Advanced memory pressure detection and system resource monitoring
@MainActor
final class MemoryPressureDetector: MemoryPressureDetectorProtocol, ObservableObject, @unchecked Sendable {

    // MARK: - Configuration

    private struct DetectionConfig {
        static let monitoringInterval: TimeInterval = 15.0 // Check every 15 seconds
        // Static floors to avoid thresholds that are too low on newer devices
        static let minPressureMB: Double = 250.0
        static let minCriticalMB: Double = 500.0
        static let lowStorageThreshold: Double = 1.0 // GB
        static let batteryLowThreshold: Float = 0.2 // 20%
        static let thermalWarningThreshold: Int = 2 // Only warn at .serious or higher
    }

    /// Compute dynamic thresholds based on device RAM (with sensible floors)
    private func dynamicThresholds() -> (pressure: Double, critical: Double) {
        let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0)
        // Pressure at ~8% of RAM, Critical at ~15% of RAM, bounded by floors
        let pressure = max(DetectionConfig.minPressureMB, totalMB * 0.08)
        let critical = max(DetectionConfig.minCriticalMB, totalMB * 0.15)
        return (pressure, critical)
    }

    // MARK: - Published Properties

    @Published var isUnderMemoryPressure = false
    @Published var currentMemoryMetrics = MemoryMetrics()

    // MARK: - Properties

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
        let thresholds = dynamicThresholds()
        let memoryPressure = metrics.memoryUsageMB > thresholds.pressure
        let thermalPressure = metrics.thermalState.rawValue >= DetectionConfig.thermalWarningThreshold
        let storagePressure = metrics.availableStorageGB < DetectionConfig.lowStorageThreshold
        let batteryPressure = metrics.batteryLevel >= 0 && metrics.batteryLevel < DetectionConfig.batteryLowThreshold

        let newPressureState = memoryPressure || thermalPressure || storagePressure || batteryPressure

        if newPressureState != isUnderMemoryPressure {
            await updateMemoryPressure(newPressureState)
        }

        // Log significant changes
        if newPressureState {
            let thresholds = dynamicThresholds()
            logger.debug("🧠 MemoryPressureDetector: Pressure factors - Memory: \(memoryPressure) (\(String(format: "%.0f", metrics.memoryUsageMB))MB > \(String(format: "%.0f", thresholds.pressure))MB), Thermal: \(thermalPressure), Storage: \(storagePressure), Battery: \(batteryPressure)")
        }
    }

    private func updateMemoryPressure(_ underPressure: Bool) async {
        let previousState = isUnderMemoryPressure
        isUnderMemoryPressure = underPressure

        if previousState != underPressure {
            let stateDescription = underPressure ? "detected" : "relieved"
            logger.info("🧠 MemoryPressureDetector: Memory pressure \(stateDescription)")

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

        // Thermal state
        metrics.thermalState = ProcessInfo.processInfo.thermalState

        // Storage information
        metrics.availableStorageGB = getAvailableStorage()

        // CPU usage
        metrics.cpuUsage = getCPUUsage()

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
}

// MARK: - Memory Metrics

/// Comprehensive system memory and resource metrics
public struct MemoryMetrics: Sendable {
    var memoryUsageMB: Double = 0
    var availableStorageGB: Double = 0
    var batteryLevel: Float = -1 // -1 if unknown
    var thermalState: ProcessInfo.ThermalState = .nominal
    var cpuUsage: Double = 0
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let memoryPressureStateChanged = Notification.Name("memoryPressureStateChanged")
}
