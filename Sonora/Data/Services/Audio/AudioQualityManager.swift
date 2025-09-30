//
//  AudioQualityManager.swift
//  Sonora
//
//  Profile-based audio quality management with intelligent adaptation
//  Optimizes recording settings based on content type, system conditions, and user preferences
//

import AVFoundation
import Foundation
import UIKit

/// Protocol defining audio quality management operations
@MainActor
protocol AudioQualityManagerProtocol: Sendable {
    var currentProfile: AudioQualityProfile { get }
    var isAdaptiveMode: Bool { get }

    func setProfile(_ profile: AudioQualityProfile)
    func getOptimalSettings(for contentType: AudioContentType) -> AudioRecordingSettings
    func enableAdaptiveMode(_ enabled: Bool)
    func getQualityMetrics() -> AudioQualityMetrics
}

/// Intelligent audio quality management service
@MainActor
final class AudioQualityManager: AudioQualityManagerProtocol, ObservableObject, @unchecked Sendable {

    // MARK: - Configuration

    private let config = AppConfiguration.shared
    private let logger = Logger.shared

    // MARK: - Published Properties

    @Published var currentProfile: AudioQualityProfile {
        didSet {
            UserDefaults.standard.set(currentProfile.rawValue, forKey: "audioQualityProfile")
            logger.info("🎚️ AudioQualityManager: Profile changed to \(currentProfile.displayName)")
        }
    }

    @Published var isAdaptiveMode: Bool {
        didSet {
            UserDefaults.standard.set(isAdaptiveMode, forKey: "adaptiveAudioMode")
            logger.info("🎚️ AudioQualityManager: Adaptive mode \(isAdaptiveMode ? "enabled" : "disabled")")
        }
    }

    // MARK: - Private Properties

    private var qualityMetrics = AudioQualityMetrics()
    private let systemMonitor = SystemConditionMonitor()

    // MARK: - Initialization

    init() {
        // Load saved preferences
        let savedProfile = UserDefaults.standard.string(forKey: "audioQualityProfile") ?? AudioQualityProfile.voiceOptimized.rawValue
        self.currentProfile = AudioQualityProfile(rawValue: savedProfile) ?? .voiceOptimized

        self.isAdaptiveMode = UserDefaults.standard.object(forKey: "adaptiveAudioMode") as? Bool ?? true

        logger.info("🎚️ AudioQualityManager: Initialized with profile: \(currentProfile.displayName), adaptive: \(isAdaptiveMode)")
    }

    // MARK: - Public Interface

    /// Sets the audio quality profile
    /// - Parameter profile: The audio quality profile to apply
    func setProfile(_ profile: AudioQualityProfile) {
        let previousProfile = currentProfile
        currentProfile = profile

        qualityMetrics.profileChanges += 1
        qualityMetrics.lastProfileChange = Date()

        logger.info("🎚️ AudioQualityManager: Profile changed from \(previousProfile.displayName) to \(profile.displayName)")
    }

    /// Returns optimal recording settings for the specified content type
    /// - Parameter contentType: The type of content being recorded
    /// - Returns: Optimized audio recording settings
    func getOptimalSettings(for contentType: AudioContentType = .voice) -> AudioRecordingSettings {
        let baseSettings = getProfileBaseSettings(for: contentType)

        guard isAdaptiveMode else {
            qualityMetrics.nonAdaptiveRequests += 1
            return baseSettings
        }

        // Apply adaptive optimizations
        let systemConditions = systemMonitor.getCurrentConditions()
        let adaptedSettings = adaptSettings(baseSettings, for: systemConditions)

        qualityMetrics.adaptiveRequests += 1
        qualityMetrics.lastAdaptation = Date()

        logger.debug("🎚️ AudioQualityManager: Optimized settings - SR: \(adaptedSettings.sampleRate)Hz, BR: \(adaptedSettings.bitRate)bps, Q: \(adaptedSettings.quality)")

        return adaptedSettings
    }

    /// Enables or disables adaptive audio quality mode
    /// - Parameter enabled: Whether to enable adaptive mode
    func enableAdaptiveMode(_ enabled: Bool) {
        isAdaptiveMode = enabled
    }

    /// Returns current quality management metrics
    func getQualityMetrics() -> AudioQualityMetrics {
        qualityMetrics
    }

    // MARK: - Private Implementation

    private func getProfileBaseSettings(for contentType: AudioContentType) -> AudioRecordingSettings {
        switch currentProfile {
        case .voiceOptimized:
            return AudioRecordingSettings(
                sampleRate: config.voiceOptimizedSampleRate,
                bitRate: config.audioBitRate,
                quality: config.voiceOptimizedQuality,
                channels: 1,
                format: .mpeg4AAC
            )

        case .highQuality:
            return AudioRecordingSettings(
                sampleRate: config.highQualitySampleRate,
                bitRate: contentType == .music ? 192_000 : 128_000,
                quality: config.recordingQuality,
                channels: contentType == .music ? 2 : 1,
                format: .mpeg4AAC
            )

        case .balanced:
            return AudioRecordingSettings(
                sampleRate: contentType == .voice ? 22_050.0 : 44_100.0,
                bitRate: contentType == .voice ? 64_000 : 96_000,
                quality: 0.75,
                channels: 1,
                format: .mpeg4AAC
            )

        case .batterySaver:
            return AudioRecordingSettings(
                sampleRate: 16_000.0, // Minimal acceptable for voice
                bitRate: 32_000,
                quality: 0.5,
                channels: 1,
                format: .mpeg4AAC
            )

        case .custom:
            return getCustomSettings(for: contentType)
        }
    }

    private func adaptSettings(_ baseSettings: AudioRecordingSettings, for conditions: SystemConditions) -> AudioRecordingSettings {
        var adaptedSettings = baseSettings

        // Battery level adaptation
        if conditions.batteryLevel >= 0 && conditions.batteryLevel < 0.2 {
            // Low battery: reduce quality significantly
            adaptedSettings.quality *= 0.7
            adaptedSettings.bitRate = max(32_000, Int(Double(adaptedSettings.bitRate) * 0.6))
            qualityMetrics.batteryOptimizations += 1
        } else if conditions.batteryLevel >= 0 && conditions.batteryLevel < 0.4 {
            // Medium battery: moderate reduction
            adaptedSettings.quality *= 0.85
            adaptedSettings.bitRate = Int(Double(adaptedSettings.bitRate) * 0.8)
        }

        // Thermal state adaptation
        switch conditions.thermalState {
        case .serious:
            adaptedSettings.quality *= 0.8
            adaptedSettings.bitRate = Int(Double(adaptedSettings.bitRate) * 0.75)
            qualityMetrics.thermalOptimizations += 1

        case .critical:
            adaptedSettings.quality *= 0.6
            adaptedSettings.bitRate = max(32_000, Int(Double(adaptedSettings.bitRate) * 0.5))
            // Switch to lower sample rate if possible
            if adaptedSettings.sampleRate > 22_050 {
                adaptedSettings.sampleRate = 22_050.0
            }
            qualityMetrics.thermalOptimizations += 1

        default:
            break
        }

        // Available storage adaptation
        if conditions.availableStorageGB < 1.0 {
            // Very low storage: aggressive compression
            adaptedSettings.bitRate = max(24_000, Int(Double(adaptedSettings.bitRate) * 0.4))
            adaptedSettings.quality *= 0.6
            qualityMetrics.storageOptimizations += 1
        } else if conditions.availableStorageGB < 5.0 {
            // Low storage: moderate compression
            adaptedSettings.bitRate = Int(Double(adaptedSettings.bitRate) * 0.7)
            adaptedSettings.quality *= 0.8
        }

        // Memory pressure adaptation
        if conditions.isUnderMemoryPressure {
            // Reduce sample rate to lower memory usage during recording
            if adaptedSettings.sampleRate > 22_050 {
                adaptedSettings.sampleRate = 22_050.0
            }
            qualityMetrics.memoryOptimizations += 1
        }

        // Ensure minimum quality thresholds
        adaptedSettings.quality = max(0.3, min(1.0, adaptedSettings.quality))
        adaptedSettings.bitRate = max(16_000, min(320_000, adaptedSettings.bitRate))

        return adaptedSettings
    }

    private func getCustomSettings(for contentType: AudioContentType) -> AudioRecordingSettings {
        // Custom settings could be loaded from UserDefaults or a configuration file
        // For now, return balanced settings as default
        getProfileBaseSettings(for: contentType)
    }
}

// MARK: - Audio Quality Profile

/// Predefined audio quality profiles
public enum AudioQualityProfile: String, CaseIterable, Sendable {
    case voiceOptimized = "voice_optimized"
    case balanced
    case highQuality = "high_quality"
    case batterySaver = "battery_saver"
    case custom

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .voiceOptimized:
            return "Voice Optimized"
        case .balanced:
            return "Balanced"
        case .highQuality:
            return "High Quality"
        case .batterySaver:
            return "Battery Saver"
        case .custom:
            return "Custom"
        }
    }

    /// Profile description for settings UI
    public var description: String {
        switch self {
        case .voiceOptimized:
            return "Optimized for voice recordings with excellent clarity and minimal file size"
        case .balanced:
            return "Good quality for most content types with reasonable file sizes"
        case .highQuality:
            return "Maximum quality for important recordings and music"
        case .batterySaver:
            return "Minimizes battery usage and storage space"
        case .custom:
            return "User-defined settings"
        }
    }
}

// MARK: - Audio Recording Settings

/// Complete set of audio recording parameters
public struct AudioRecordingSettings: Sendable {
    var sampleRate: Double
    var bitRate: Int
    var quality: Float
    var channels: Int
    var format: AudioFormat

    /// Estimated file size per minute of recording (in MB)
    var estimatedFileSizePerMinute: Double {
        // Approximate calculation: (bitRate * 60 seconds) / 8 / 1024 / 1024
        Double(bitRate) * 60.0 / 8.0 / 1_024.0 / 1_024.0
    }

    /// Battery usage impact (relative scale: 1.0 = normal, >1.0 = higher usage)
    var batteryImpactFactor: Double {
        let baseFactor = sampleRate > 22_050 ? 1.2 : 1.0
        let qualityFactor = quality > 0.8 ? 1.15 : (quality < 0.5 ? 0.85 : 1.0)
        return baseFactor * qualityFactor
    }
}

/// Audio format options
public enum AudioFormat: String, CaseIterable, Sendable {
    case mpeg4AAC = "m4a"
    case appleLossless = "alac"
    case linearPCM = "wav"

    var displayName: String {
        switch self {
        case .mpeg4AAC:
            return "AAC (M4A)"
        case .appleLossless:
            return "Apple Lossless"
        case .linearPCM:
            return "WAV (Uncompressed)"
        }
    }
}

// MARK: - System Monitoring

/// Monitors system conditions for adaptive quality management
@MainActor
private class SystemConditionMonitor: @unchecked Sendable {

    func getCurrentConditions() -> SystemConditions {
        let device = UIDevice.current

        // Enable battery monitoring if not already enabled
        if !device.isBatteryMonitoringEnabled {
            device.isBatteryMonitoringEnabled = true
        }

        return SystemConditions(
            batteryLevel: device.batteryLevel,
            batteryState: device.batteryState,
            thermalState: ProcessInfo.processInfo.thermalState,
            availableStorageGB: getAvailableStorageGB(),
            isUnderMemoryPressure: isUnderMemoryPressure()
        )
    }

    private func getAvailableStorageGB() -> Double {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                return freeSpace.doubleValue / (1_024.0 * 1_024.0 * 1_024.0) // Convert to GB
            }
        } catch {
            print("🎚️ AudioQualityManager: Failed to get storage info: \(error)")
        }
        return 100.0 // Default assumption if we can't determine
    }

    private func isUnderMemoryPressure() -> Bool {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let memoryUsage = Double(info.resident_size) / 1_024.0 / 1_024.0 // MB
            return memoryUsage > 150.0 // Consider >150MB as memory pressure
        }

        return false
    }
}

// MARK: - System Conditions

/// Current system conditions for adaptive optimization
private struct SystemConditions {
    let batteryLevel: Float // -1 if unknown, 0.0-1.0 otherwise
    let batteryState: UIDevice.BatteryState
    let thermalState: ProcessInfo.ThermalState
    let availableStorageGB: Double
    let isUnderMemoryPressure: Bool
}

// MARK: - Quality Metrics

/// Performance metrics for audio quality management
public struct AudioQualityMetrics: Sendable {
    var profileChanges: Int = 0
    var adaptiveRequests: Int = 0
    var nonAdaptiveRequests: Int = 0
    var batteryOptimizations: Int = 0
    var thermalOptimizations: Int = 0
    var storageOptimizations: Int = 0
    var memoryOptimizations: Int = 0

    var lastProfileChange: Date?
    var lastAdaptation: Date?

    /// Percentage of requests that used adaptive optimization
    var adaptiveUsageRate: Double {
        let total = adaptiveRequests + nonAdaptiveRequests
        return total > 0 ? Double(adaptiveRequests) / Double(total) : 0.0
    }

    /// Total number of system-condition optimizations performed
    var totalOptimizations: Int {
        batteryOptimizations + thermalOptimizations + storageOptimizations + memoryOptimizations
    }
}
