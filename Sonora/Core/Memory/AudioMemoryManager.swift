import Foundation
import AVFoundation
import Combine
import UIKit

/// Protocol for dependency injection and testing
public protocol AudioMemoryManagerProtocol {
    var currentMemoryUsage: Int64 { get async }
    var availableStorageSpace: Int64 { get async }
    var totalAudioFiles: Int { get async }
    
    func startMonitoring()
    func stopMonitoring()
    func performCleanup() async throws
    func compressOldRecordings() async throws
    func removeTemporaryFiles() async throws
}

/// Comprehensive audio memory manager handling file lifecycle, storage monitoring, and automatic cleanup
/// Integrates with Sonora's existing architecture patterns and configuration system
@MainActor
public final class AudioMemoryManager: ObservableObject, AudioMemoryManagerProtocol {
    
    // MARK: - Published Properties
    
    @Published public var currentMemoryUsage: Int64 = 0
    @Published public var availableStorageSpace: Int64 = 0
    @Published public var totalAudioFiles: Int = 0
    @Published public var memoryPressureLevel: MemoryPressureLevel = .normal
    @Published public var isPerformingCleanup: Bool = false
    @Published public var lastCleanupDate: Date?
    
    // MARK: - Dependencies
    
    private let logger: LoggerProtocol
    private let configuration: AppConfiguration
    private let fileManager: FileManager
    private let documentsDirectory: URL
    
    // MARK: - Internal State
    
    private var monitoringTimer: Timer?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private let processingQueue = DispatchQueue(label: "com.sonora.audio-memory", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    /// Memory usage thresholds and cleanup policies
    private struct MemoryConfiguration {
        // Storage thresholds (in bytes)
        static let lowStorageThreshold: Int64 = 500 * 1024 * 1024 // 500MB
        static let criticalStorageThreshold: Int64 = 100 * 1024 * 1024 // 100MB
        
        // File age thresholds for compression/cleanup
        static let compressionAgeThreshold: TimeInterval = 30 * 24 * 3600 // 30 days
        static let cleanupAgeThreshold: TimeInterval = 90 * 24 * 3600 // 90 days
        
        // Monitoring intervals
        static let monitoringInterval: TimeInterval = 30.0 // 30 seconds
        static let cleanupCooldownPeriod: TimeInterval = 3600.0 // 1 hour
        
        // Compression settings
        static let compressionQuality: Float = 0.6 // Moderate compression for old files
        static let maxConcurrentCompressions: Int = 2
    }
    
    // MARK: - Initialization
    
    public init(
        logger: LoggerProtocol = Logger.shared,
        configuration: AppConfiguration = AppConfiguration.shared,
        fileManager: FileManager = .default
    ) {
        self.logger = logger
        self.configuration = configuration
        self.fileManager = fileManager
        
        // Get documents directory
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        setupMemoryPressureMonitoring()
        
        Task {
            await updateMetrics()
        }
        
        logger.info("AudioMemoryManager initialized", 
                   category: .system, 
                   context: LogContext())
    }
    
    deinit {
        monitoringTimer?.invalidate()
        memoryPressureSource?.cancel()
        logger.info("AudioMemoryManager deinitialized", 
                   category: .system, 
                   context: LogContext())
    }
    
    // MARK: - Public Interface
    
    /// Start automatic monitoring and periodic cleanup
    public func startMonitoring() {
        guard monitoringTimer == nil else {
            logger.warning("AudioMemoryManager: Monitoring already active", 
                          category: .system, 
                          context: LogContext(), 
                          error: nil)
            return
        }
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: MemoryConfiguration.monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performPeriodicMaintenance()
            }
        }
        
        logger.info("AudioMemoryManager: Monitoring started", 
                   category: .system, 
                   context: LogContext())
    }
    
    /// Stop automatic monitoring
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        
        logger.info("AudioMemoryManager: Monitoring stopped", 
                   category: .system, 
                   context: LogContext())
    }
    
    /// Perform comprehensive cleanup of audio files and temporary data
    public func performCleanup() async throws {
        let timer = PerformanceTimer(operation: "AudioMemoryManager.performCleanup", 
                                   category: .performance, 
                                   logger: logger)
        
        isPerformingCleanup = true
        defer { isPerformingCleanup = false }
        
        do {
            // Step 1: Remove temporary and orphaned files
            try await removeTemporaryFiles()
            
            // Step 2: Compress old recordings if storage is low
            if availableStorageSpace < MemoryConfiguration.lowStorageThreshold {
                try await compressOldRecordings()
            }
            
            // Step 3: Remove very old files if still low on space
            if availableStorageSpace < MemoryConfiguration.criticalStorageThreshold {
                try await removeOldRecordings()
            }
            
            // Step 4: Update metrics
            await updateMetrics()
            
            lastCleanupDate = Date()
            
            let duration = timer.finish()
            logger.info("AudioMemoryManager: Cleanup completed successfully", 
                       category: .system, 
                       context: LogContext(additionalInfo: [
                           "duration": duration,
                           "freedSpace": availableStorageSpace,
                           "remainingFiles": totalAudioFiles
                       ]))
            
        } catch {
            logger.error("AudioMemoryManager: Cleanup failed", 
                        category: .system, 
                        context: LogContext(), 
                        error: error)
            throw error
        }
    }
    
    /// Compress recordings older than the configured threshold
    public func compressOldRecordings() async throws {
        let timer = PerformanceTimer(operation: "AudioMemoryManager.compressOldRecordings", 
                                   category: .performance, 
                                   logger: logger)
        
        logger.info("AudioMemoryManager: Starting compression of old recordings", 
                   category: .system, 
                   context: LogContext())
        
        let audioFiles = try await getAudioFiles()
        let cutoffDate = Date().addingTimeInterval(-MemoryConfiguration.compressionAgeThreshold)
        
        let oldFiles = audioFiles.filter { fileInfo in
            fileInfo.creationDate < cutoffDate && !fileInfo.isCompressed
        }.prefix(MemoryConfiguration.maxConcurrentCompressions)
        
        logger.info("AudioMemoryManager: Found \(oldFiles.count) files for compression", 
                   category: .system, 
                   context: LogContext())
        
        var compressedCount = 0
        var totalSpaceSaved: Int64 = 0
        
        for fileInfo in oldFiles {
            do {
                let spaceSaved = try await compressAudioFile(fileInfo)
                compressedCount += 1
                totalSpaceSaved += spaceSaved
                
                logger.debug("AudioMemoryManager: Compressed \(fileInfo.url.lastPathComponent)", 
                            category: .system, 
                            context: LogContext(additionalInfo: [
                                "spaceSaved": spaceSaved,
                                "originalSize": fileInfo.size
                            ]))
            } catch {
                logger.warning("AudioMemoryManager: Failed to compress \(fileInfo.url.lastPathComponent)", 
                              category: .system, 
                              context: LogContext(), 
                              error: error)
            }
        }
        
        timer.finish(additionalInfo: "Compressed \(compressedCount) files, saved \(ByteCountFormatter().string(fromByteCount: totalSpaceSaved))")
    }
    
    /// Remove temporary files and cleanup artifacts
    public func removeTemporaryFiles() async throws {
        logger.info("AudioMemoryManager: Cleaning temporary files", 
                   category: .system, 
                   context: LogContext())
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AudioMemoryError.internalError("AudioMemoryManager deallocated"))
                    return
                }
                
                do {
                    var removedCount = 0
                    var freedSpace: Int64 = 0
                    
                    // Find temporary files (partial downloads, transcoding artifacts, etc.)
                    let tempPatterns = [".tmp", ".temp", ".partial", ".transcoding"]
                    let contents = try self.fileManager.contentsOfDirectory(
                        at: self.documentsDirectory,
                        includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                        options: .skipsHiddenFiles
                    )
                    
                    for url in contents {
                        let filename = url.lastPathComponent.lowercased()
                        
                        // Remove files matching temporary patterns
                        if tempPatterns.contains(where: { filename.hasSuffix($0) }) {
                            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
                            let fileSize = Int64(resources.fileSize ?? 0)
                            
                            try self.fileManager.removeItem(at: url)
                            removedCount += 1
                            freedSpace += fileSize
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.logger.info("AudioMemoryManager: Removed \(removedCount) temporary files", 
                                        category: .system, 
                                        context: LogContext(additionalInfo: [
                                            "freedSpace": freedSpace
                                        ]))
                    }
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Implementation
    
    /// Setup memory pressure monitoring using dispatch sources
    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: processingQueue)
        
        memoryPressureSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let pressureLevel = self.memoryPressureSource?.data ?? []
            
            Task { @MainActor [weak self] in
                await self?.handleMemoryPressure(pressureLevel)
            }
        }
        
        memoryPressureSource?.resume()
    }
    
    /// Handle memory pressure events
    private func handleMemoryPressure(_ pressureLevel: DispatchSource.MemoryPressureEvent) async {
        let newLevel: MemoryPressureLevel
        
        if pressureLevel.contains(.critical) {
            newLevel = .critical
        } else if pressureLevel.contains(.warning) {
            newLevel = .warning
        } else {
            newLevel = .normal
        }
        
        guard newLevel != memoryPressureLevel else { return }
        
        memoryPressureLevel = newLevel
        
        logger.warning("AudioMemoryManager: Memory pressure level changed to \(newLevel)", 
                      category: .system, 
                      context: LogContext(), 
                      error: nil)
        
        // Trigger cleanup for warning/critical levels
        if newLevel != .normal {
            Task {
                try? await performCleanup()
            }
        }
    }
    
    /// Perform periodic maintenance tasks
    private func performPeriodicMaintenance() async {
        await updateMetrics()
        
        // Perform cleanup if storage is low and enough time has passed
        let shouldCleanup = availableStorageSpace < MemoryConfiguration.lowStorageThreshold
        let cooldownPassed = lastCleanupDate?.timeIntervalSinceNow ?? -MemoryConfiguration.cleanupCooldownPeriod < -MemoryConfiguration.cleanupCooldownPeriod
        
        if shouldCleanup && cooldownPassed && !isPerformingCleanup {
            logger.info("AudioMemoryManager: Triggering automatic cleanup", 
                       category: .system, 
                       context: LogContext(additionalInfo: [
                           "availableSpace": availableStorageSpace,
                           "threshold": MemoryConfiguration.lowStorageThreshold
                       ]))
            
            Task {
                try? await performCleanup()
            }
        }
    }
    
    /// Update memory and storage metrics
    private func updateMetrics() async {
        do {
            let audioFiles = try await getAudioFiles()
            let memoryUsage = audioFiles.reduce(0) { $0 + $1.size }
            let storage = try getAvailableStorageSpace()
            
            await MainActor.run {
                self.currentMemoryUsage = memoryUsage
                self.availableStorageSpace = storage
                self.totalAudioFiles = audioFiles.count
            }
            
        } catch {
            logger.error("AudioMemoryManager: Failed to update metrics", 
                        category: .system, 
                        context: LogContext(), 
                        error: error)
        }
    }
    
    /// Get all audio files in the documents directory
    private func getAudioFiles() async throws -> [AudioFileInfo] {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AudioMemoryError.internalError("AudioMemoryManager deallocated"))
                    return
                }
                
                do {
                    let contents = try self.fileManager.contentsOfDirectory(
                        at: self.documentsDirectory,
                        includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey],
                        options: .skipsHiddenFiles
                    )
                    
                    let audioExtensions = ["m4a", "mp3", "wav", "aac"]
                    var audioFiles: [AudioFileInfo] = []
                    
                    for url in contents {
                        let pathExtension = url.pathExtension.lowercased()
                        
                        if audioExtensions.contains(pathExtension) {
                            let resources = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                            
                            let fileInfo = AudioFileInfo(
                                url: url,
                                size: Int64(resources.fileSize ?? 0),
                                creationDate: resources.creationDate ?? Date(),
                                isCompressed: self.isFileCompressed(url)
                            )
                            
                            audioFiles.append(fileInfo)
                        }
                    }
                    
                    continuation.resume(returning: audioFiles)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Get available storage space on device
    private func getAvailableStorageSpace() throws -> Int64 {
        let systemAttributes = try fileManager.attributesOfFileSystem(forPath: documentsDirectory.path)
        return systemAttributes[.systemFreeSize] as? Int64 ?? 0
    }
    
    /// Check if audio file is already compressed
    private func isFileCompressed(_ url: URL) -> Bool {
        // Check for compressed file indicators (lower bitrate, smaller size relative to duration, etc.)
        // For now, use simple heuristics - could be enhanced with actual audio analysis
        return url.lastPathComponent.contains(".compressed") || url.pathExtension == "aac"
    }
    
    /// Compress a single audio file
    private func compressAudioFile(_ fileInfo: AudioFileInfo) async throws -> Int64 {
        let originalSize = fileInfo.size
        let tempURL = fileInfo.url.appendingPathExtension("temp")
        
        // Use AVAssetExportSession for compression
        let asset = AVAsset(url: fileInfo.url)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            throw AudioMemoryError.compressionFailed("Unable to create export session")
        }
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = true
        
        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    do {
                        // Replace original with compressed version
                        _ = try self.fileManager.replaceItem(at: fileInfo.url, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
                        
                        let newSize = try self.fileManager.attributesOfItem(atPath: fileInfo.url.path)[.size] as? Int64 ?? 0
                        let spaceSaved = originalSize - newSize
                        
                        continuation.resume(returning: spaceSaved)
                        
                    } catch {
                        continuation.resume(throwing: AudioMemoryError.compressionFailed("Failed to replace original file: \(error)"))
                    }
                    
                case .failed, .cancelled:
                    let error = exportSession.error ?? AudioMemoryError.compressionFailed("Unknown compression error")
                    continuation.resume(throwing: error)
                    
                default:
                    continuation.resume(throwing: AudioMemoryError.compressionFailed("Unexpected export session status: \(exportSession.status)"))
                }
            }
        }
    }
    
    /// Remove very old recordings when storage is critically low
    private func removeOldRecordings() async throws {
        logger.warning("AudioMemoryManager: Removing old recordings due to critical storage", 
                      category: .system, 
                      context: LogContext(), 
                      error: nil)
        
        let audioFiles = try await getAudioFiles()
        let cutoffDate = Date().addingTimeInterval(-MemoryConfiguration.cleanupAgeThreshold)
        
        let oldFiles = audioFiles.filter { $0.creationDate < cutoffDate }
            .sorted { $0.creationDate < $1.creationDate }
        
        var removedCount = 0
        var freedSpace: Int64 = 0
        
        for fileInfo in oldFiles {
            do {
                try fileManager.removeItem(at: fileInfo.url)
                removedCount += 1
                freedSpace += fileInfo.size
                
                // Stop if we've freed enough space
                if availableStorageSpace + freedSpace > MemoryConfiguration.lowStorageThreshold {
                    break
                }
            } catch {
                logger.warning("AudioMemoryManager: Failed to remove \(fileInfo.url.lastPathComponent)", 
                              category: .system, 
                              context: LogContext(), 
                              error: error)
            }
        }
        
        logger.warning("AudioMemoryManager: Removed \(removedCount) old recordings", 
                      category: .system, 
                      context: LogContext(additionalInfo: [
                          "freedSpace": freedSpace
                      ]), 
                      error: nil)
    }
}

// MARK: - Supporting Types

/// Memory pressure levels for monitoring system health
public enum MemoryPressureLevel: String, CaseIterable {
    case normal = "normal"
    case warning = "warning"
    case critical = "critical"
}

/// Information about an audio file
public struct AudioFileInfo {
    let url: URL
    let size: Int64
    let creationDate: Date
    let isCompressed: Bool
    
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
    }
    
    var formattedSize: String {
        ByteCountFormatter().string(fromByteCount: size)
    }
}

/// Errors specific to audio memory management
public enum AudioMemoryError: LocalizedError {
    case internalError(String)
    case compressionFailed(String)
    case cleanupFailed(String)
    case insufficientPermissions
    
    public var errorDescription: String? {
        switch self {
        case .internalError(let message):
            return "Internal memory manager error: \(message)"
        case .compressionFailed(let message):
            return "Audio compression failed: \(message)"
        case .cleanupFailed(let message):
            return "Cleanup operation failed: \(message)"
        case .insufficientPermissions:
            return "Insufficient permissions to manage audio files"
        }
    }
}