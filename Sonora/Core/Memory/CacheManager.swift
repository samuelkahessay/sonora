import Foundation
import Combine

/// Protocol for dependency injection and testing
public protocol CacheManagerProtocol {
    func set<T: Codable>(_ value: T, forKey key: String, category: CacheCategory) async
    func get<T: Codable>(_ type: T.Type, forKey key: String, category: CacheCategory) async -> T?
    func remove(forKey key: String, category: CacheCategory) async
    func clearCategory(_ category: CacheCategory) async
    func clearExpiredItems() async
    func getCacheStatistics() async -> CacheStatistics
}

/// Categories for organizing cached data
public enum CacheCategory: String, CaseIterable, Codable {
    case transcription = "transcription"
    case analysis = "analysis"
    case audioMetadata = "audio_metadata"
    case userPreferences = "user_preferences"
    
    var displayName: String {
        switch self {
        case .transcription: return "Transcription"
        case .analysis: return "Analysis"
        case .audioMetadata: return "Audio Metadata"
        case .userPreferences: return "User Preferences"
        }
    }
    
    /// Default TTL for each category
    var defaultTTL: TimeInterval {
        switch self {
        case .transcription: return 7 * 24 * 3600 // 7 days
        case .analysis: return 24 * 3600 // 24 hours
        case .audioMetadata: return 30 * 24 * 3600 // 30 days
        case .userPreferences: return 365 * 24 * 3600 // 1 year
        }
    }
}

/// High-performance LRU cache with memory and disk tiers
/// Supports automatic eviction, TTL expiration, and memory pressure handling
public actor CacheManager: CacheManagerProtocol {
    
    // MARK: - Dependencies
    
    private let logger: LoggerProtocol
    private let configuration: AppConfiguration
    private let fileManager: FileManager
    private let cacheDirectory: URL
    
    // MARK: - Cache Storage
    
    private var memoryCache: [String: CacheEntry] = [:]
    private var accessOrder: LinkedList<String> = LinkedList()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Configuration
    
    private struct CacheConfiguration {
        // Memory cache limits
        static let maxMemoryItems: Int = 100
        static let maxMemorySize: Int64 = 50 * 1024 * 1024 // 50MB
        
        // Disk cache limits
        static let maxDiskSize: Int64 = 500 * 1024 * 1024 // 500MB
        static let maxDiskItems: Int = 10000
        
        // Maintenance intervals
        static let cleanupInterval: TimeInterval = 3600 // 1 hour
        static let statisticsUpdateInterval: TimeInterval = 300 // 5 minutes
        
        // Eviction policies
        static let memoryPressureEvictionRatio: Double = 0.3 // Evict 30% on pressure
        static let diskFullEvictionRatio: Double = 0.2 // Evict 20% when disk full
    }
    
    // MARK: - Statistics
    
    private var statistics = CacheStatistics()
    private var cleanupTimer: Task<Void, Never>?
    private var isInitialized = false
    
    // MARK: - Initialization
    
    public init(
        logger: LoggerProtocol = Logger.shared,
        configuration: AppConfiguration = AppConfiguration.shared,
        fileManager: FileManager = .default
    ) async {
        self.logger = logger
        self.configuration = configuration
        self.fileManager = fileManager
        
        // Setup cache directory
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documentsDirectory.appendingPathComponent("Cache", isDirectory: true)
        
        await initializeCache()
        startPeriodicCleanup()
        
        logger.info("CacheManager initialized", 
                   category: .system, 
                   context: LogContext())
    }
    
    deinit {
        cleanupTimer?.cancel()
    }
    
    // MARK: - Public Interface
    
    /// Store a value in the cache with automatic TTL
    public func set<T: Codable>(_ value: T, forKey key: String, category: CacheCategory) async {
        let timer = PerformanceTimer(operation: "CacheManager.set", category: .performance, logger: logger)
        
        do {
            let data = try encoder.encode(value)
            let entry = CacheEntry(
                key: key,
                data: data,
                category: category,
                size: Int64(data.count),
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(category.defaultTTL),
                accessCount: 1,
                lastAccessed: Date()
            )
            
            await storeEntry(entry)
            
            statistics.writes += 1
            timer.finish(additionalInfo: "Stored \(ByteCountFormatter().string(fromByteCount: entry.size))")
            
            logger.debug("CacheManager: Stored \(key) in \(category.rawValue)", 
                        category: .system, 
                        context: LogContext(additionalInfo: ["size": entry.size]))
            
        } catch {
            statistics.errors += 1
            logger.error("CacheManager: Failed to store \(key)", 
                        category: .system, 
                        context: LogContext(additionalInfo: ["key": key]), 
                        error: error)
        }
    }
    
    /// Retrieve a value from the cache
    public func get<T: Codable>(_ type: T.Type, forKey key: String, category: CacheCategory) async -> T? {
        let timer = PerformanceTimer(operation: "CacheManager.get", category: .performance, logger: logger)
        
        // Try memory cache first
        if var entry = memoryCache[key] {
            if entry.isExpired {
                await removeEntry(key)
                statistics.misses += 1
                return nil
            }
            
            // Update access information
            entry.accessCount += 1
            entry.lastAccessed = Date()
            memoryCache[key] = entry
            accessOrder.moveToHead(key)
            
            do {
                let value = try decoder.decode(type, from: entry.data)
                statistics.hits += 1
                statistics.memoryHits += 1
                timer.finish(additionalInfo: "Memory hit")
                return value
            } catch {
                await removeEntry(key)
                statistics.errors += 1
                logger.error("CacheManager: Failed to decode \(key)", 
                            category: .system, 
                            context: LogContext(), 
                            error: error)
                return nil
            }
        }
        
        // Try disk cache
        let diskURL = diskURL(forKey: key, category: category)
        
        if fileManager.fileExists(atPath: diskURL.path) {
            do {
                let data = try Data(contentsOf: diskURL)
                let entry = try decoder.decode(CacheEntry.self, from: data)
                
                if entry.isExpired {
                    try? fileManager.removeItem(at: diskURL)
                    statistics.misses += 1
                    return nil
                }
                
                // Move to memory cache if there's room
                if canStoreInMemory(entry.size) {
                    var updatedEntry = entry
                    updatedEntry.accessCount += 1
                    updatedEntry.lastAccessed = Date()
                    memoryCache[key] = updatedEntry
                    accessOrder.append(key)
                    await enforceMemoryLimits()
                }
                
                let value = try decoder.decode(type, from: entry.data)
                statistics.hits += 1
                statistics.diskHits += 1
                timer.finish(additionalInfo: "Disk hit")
                return value
                
            } catch {
                try? fileManager.removeItem(at: diskURL)
                statistics.errors += 1
                logger.error("CacheManager: Failed to read disk cache for \(key)", 
                            category: .system, 
                            context: LogContext(additionalInfo: ["key": key]), 
                            error: error)
            }
        }
        
        statistics.misses += 1
        timer.finish(additionalInfo: "Cache miss")
        return nil
    }
    
    /// Remove a specific cache entry
    public func remove(forKey key: String, category: CacheCategory) async {
        await removeEntry(key)
        
        let diskURL = diskURL(forKey: key, category: category)
        try? fileManager.removeItem(at: diskURL)
        
        logger.debug("CacheManager: Removed \(key) from \(category.rawValue)", 
                    category: .system, 
                    context: LogContext(additionalInfo: ["key": key, "category": category.rawValue]))
    }
    
    /// Clear all entries in a specific category
    public func clearCategory(_ category: CacheCategory) async {
        let timer = PerformanceTimer(operation: "CacheManager.clearCategory", category: .performance, logger: logger)
        
        // Remove from memory cache
        let keysToRemove = memoryCache.keys.filter { memoryCache[$0]?.category == category }
        for key in keysToRemove {
            await removeEntry(key)
        }
        
        // Remove from disk cache
        let categoryDir = cacheDirectory.appendingPathComponent(category.rawValue, isDirectory: true)
        if fileManager.fileExists(atPath: categoryDir.path) {
            try? fileManager.removeItem(at: categoryDir)
        }
        
        await createCacheDirectories()
        
        timer.finish(additionalInfo: "Cleared \(keysToRemove.count) items")
        logger.info("CacheManager: Cleared category \(category.rawValue)", 
                   category: .system, 
                   context: LogContext(additionalInfo: ["category": category.rawValue, "itemsCleared": keysToRemove.count]))
    }
    
    /// Remove expired cache entries
    public func clearExpiredItems() async {
        let timer = PerformanceTimer(operation: "CacheManager.clearExpiredItems", category: .performance, logger: logger)
        
        var removedCount = 0
        
        // Clear expired memory entries
        let expiredKeys = memoryCache.compactMap { key, entry in
            entry.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            await removeEntry(key)
            removedCount += 1
        }
        
        // Clear expired disk entries
        for category in CacheCategory.allCases {
            let categoryDir = cacheDirectory.appendingPathComponent(category.rawValue, isDirectory: true)
            
            guard fileManager.fileExists(atPath: categoryDir.path) else { continue }
            
            do {
                let contents = try fileManager.contentsOfDirectory(at: categoryDir, 
                                                                 includingPropertiesForKeys: [.contentModificationDateKey], 
                                                                 options: .skipsHiddenFiles)
                
                for fileURL in contents {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let entry = try decoder.decode(CacheEntry.self, from: data)
                        
                        if entry.isExpired {
                            try fileManager.removeItem(at: fileURL)
                            removedCount += 1
                        }
                    } catch {
                        // Remove corrupted files
                        try? fileManager.removeItem(at: fileURL)
                        removedCount += 1
                    }
                }
            } catch {
                logger.warning("CacheManager: Failed to scan category \(category.rawValue) for expired items", 
                              category: .system, 
                              context: LogContext(), 
                              error: error)
            }
        }
        
        timer.finish(additionalInfo: "Removed \(removedCount) expired items")
    }
    
    /// Get comprehensive cache statistics
    public func getCacheStatistics() async -> CacheStatistics {
        await updateStatistics()
        return statistics
    }
    
    // MARK: - Memory Pressure Handling
    
    /// Handle memory pressure by evicting least recently used items
    public func handleMemoryPressure() async {
        let itemsToEvict = Int(Double(memoryCache.count) * CacheConfiguration.memoryPressureEvictionRatio)
        await evictLeastRecentlyUsed(count: itemsToEvict, fromMemoryOnly: true)
        
        logger.info("CacheManager: Handled memory pressure, evicted \(itemsToEvict) items", 
                   category: .system, 
                   context: LogContext(additionalInfo: ["itemsEvicted": itemsToEvict]))
    }
    
    // MARK: - Private Implementation
    
    /// Initialize cache directories and load statistics
    private func initializeCache() async {
        do {
            await createCacheDirectories()
            await updateStatistics()
            isInitialized = true
        } catch {
            logger.error("CacheManager: Initialization failed", 
                        category: .system, 
                        context: LogContext(), 
                        error: error)
        }
    }
    
    /// Create cache directory structure
    private func createCacheDirectories() async {
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            
            for category in CacheCategory.allCases {
                let categoryDir = cacheDirectory.appendingPathComponent(category.rawValue, isDirectory: true)
                try fileManager.createDirectory(at: categoryDir, withIntermediateDirectories: true)
            }
        } catch {
            logger.error("CacheManager: Failed to create cache directories", 
                        category: .system, 
                        context: LogContext(), 
                        error: error)
        }
    }
    
    /// Store cache entry with appropriate tier selection
    private func storeEntry(_ entry: CacheEntry) async {
        // Try to store in memory first
        if canStoreInMemory(entry.size) {
            memoryCache[entry.key] = entry
            accessOrder.append(entry.key)
            await enforceMemoryLimits()
        }
        
        // Always store to disk for persistence
        await storeToDisk(entry)
    }
    
    /// Check if we can store an item in memory cache
    private func canStoreInMemory(_ size: Int64) -> Bool {
        let currentMemorySize = memoryCache.values.reduce(0) { $0 + $1.size }
        let currentCount = memoryCache.count
        
        return currentCount < CacheConfiguration.maxMemoryItems &&
               (currentMemorySize + size) < CacheConfiguration.maxMemorySize
    }
    
    /// Store entry to disk cache
    private func storeToDisk(_ entry: CacheEntry) async {
        let diskURL = diskURL(forKey: entry.key, category: entry.category)
        
        do {
            let data = try encoder.encode(entry)
            try data.write(to: diskURL)
        } catch {
            statistics.errors += 1
            logger.error("CacheManager: Failed to store \(entry.key) to disk", 
                        category: .system, 
                        context: LogContext(), 
                        error: error)
        }
    }
    
    /// Generate disk URL for cache entry
    private func diskURL(forKey key: String, category: CacheCategory) -> URL {
        let filename = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        return cacheDirectory
            .appendingPathComponent(category.rawValue, isDirectory: true)
            .appendingPathComponent("\(filename).cache")
    }
    
    /// Remove entry from memory cache
    private func removeEntry(_ key: String) async {
        memoryCache.removeValue(forKey: key)
        accessOrder.remove(key)
    }
    
    /// Enforce memory cache size limits
    private func enforceMemoryLimits() async {
        while memoryCache.count > CacheConfiguration.maxMemoryItems ||
              getCurrentMemorySize() > CacheConfiguration.maxMemorySize {
            
            guard let lruKey = accessOrder.tailValue else { break }
            await removeEntry(lruKey)
        }
    }
    
    /// Get current memory cache size
    private func getCurrentMemorySize() -> Int64 {
        return memoryCache.values.reduce(0) { $0 + $1.size }
    }
    
    /// Evict least recently used items
    private func evictLeastRecentlyUsed(count: Int, fromMemoryOnly: Bool = false) async {
        var evicted = 0
        
        // Evict from memory cache
        while evicted < count && !accessOrder.isEmpty {
            guard let lruKey = accessOrder.tailValue else { break }
            await removeEntry(lruKey)
            evicted += 1
        }
        
        // Optionally evict from disk cache
        if !fromMemoryOnly && evicted < count {
            await evictFromDisk(count - evicted)
        }
    }
    
    /// Evict items from disk cache
    private func evictFromDisk(_ count: Int) async {
        var evicted = 0
        
        for category in CacheCategory.allCases {
            let categoryDir = cacheDirectory.appendingPathComponent(category.rawValue, isDirectory: true)
            
            guard fileManager.fileExists(atPath: categoryDir.path) else { continue }
            
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: categoryDir,
                    includingPropertiesForKeys: [.contentAccessDateKey],
                    options: .skipsHiddenFiles
                )
                
                // Sort by last access time (oldest first)
                let sortedFiles = contents.sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate ?? Date.distantPast
                    return date1 < date2
                }
                
                for fileURL in sortedFiles.prefix(count - evicted) {
                    try? fileManager.removeItem(at: fileURL)
                    evicted += 1
                }
                
                if evicted >= count { break }
                
            } catch {
                logger.warning("CacheManager: Failed to evict from category \(category.rawValue)", 
                              category: .system, 
                              context: LogContext(), 
                              error: error)
            }
        }
    }
    
    /// Update cache statistics
    private func updateStatistics() async {
        statistics.memoryItems = memoryCache.count
        statistics.memorySize = getCurrentMemorySize()
        
        var totalDiskItems = 0
        var totalDiskSize: Int64 = 0
        
        for category in CacheCategory.allCases {
            let categoryDir = cacheDirectory.appendingPathComponent(category.rawValue, isDirectory: true)
            
            guard fileManager.fileExists(atPath: categoryDir.path) else { continue }
            
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: categoryDir,
                    includingPropertiesForKeys: [.fileSizeKey],
                    options: .skipsHiddenFiles
                )
                
                totalDiskItems += contents.count
                
                for fileURL in contents {
                    let resources = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    totalDiskSize += Int64(resources.fileSize ?? 0)
                }
            } catch {
                logger.warning("CacheManager: Failed to calculate statistics for \(category.rawValue)", 
                              category: .system, 
                              context: LogContext(), 
                              error: error)
            }
        }
        
        statistics.diskItems = totalDiskItems
        statistics.diskSize = totalDiskSize
        statistics.hitRate = statistics.totalRequests > 0 ? Double(statistics.hits) / Double(statistics.totalRequests) : 0.0
        statistics.lastUpdated = Date()
    }
    
    /// Start periodic cleanup task
    private func startPeriodicCleanup() {
        cleanupTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(CacheConfiguration.cleanupInterval * 1_000_000_000))
                
                if !Task.isCancelled {
                    await clearExpiredItems()
                    await updateStatistics()
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// Cache entry containing data and metadata
private struct CacheEntry: Codable {
    let key: String
    let data: Data
    let category: CacheCategory
    let size: Int64
    let createdAt: Date
    let expiresAt: Date
    var accessCount: Int
    var lastAccessed: Date
    
    init(key: String, data: Data, category: CacheCategory, size: Int64, createdAt: Date, expiresAt: Date, accessCount: Int, lastAccessed: Date) {
        self.key = key
        self.data = data
        self.category = category
        self.size = size
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.accessCount = accessCount
        self.lastAccessed = lastAccessed
    }
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var ageInSeconds: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }
}

/// Cache performance and usage statistics
public struct CacheStatistics: Codable {
    public var hits: Int = 0
    public var misses: Int = 0
    public var memoryHits: Int = 0
    public var diskHits: Int = 0
    public var writes: Int = 0
    public var errors: Int = 0
    
    public var memoryItems: Int = 0
    public var diskItems: Int = 0
    public var memorySize: Int64 = 0
    public var diskSize: Int64 = 0
    
    public var hitRate: Double = 0.0
    public var lastUpdated: Date = Date()
    
    public var totalRequests: Int {
        return hits + misses
    }
    
    public var totalItems: Int {
        return memoryItems + diskItems
    }
    
    public var totalSize: Int64 {
        return memorySize + diskSize
    }
    
    public var formattedSizes: (memory: String, disk: String, total: String) {
        let formatter = ByteCountFormatter()
        return (
            memory: formatter.string(fromByteCount: memorySize),
            disk: formatter.string(fromByteCount: diskSize),
            total: formatter.string(fromByteCount: totalSize)
        )
    }
}

/// Simple doubly-linked list for LRU tracking
private class LinkedList<T: Hashable> {
    private var head: Node<T>?
    private var tail: Node<T>?
    private var nodeMap: [T: Node<T>] = [:]
    
    var isEmpty: Bool { head == nil }
    
    var tailValue: T? {
        return tail?.value
    }
    
    func append(_ value: T) {
        let node = Node(value: value)
        nodeMap[value] = node
        
        if head == nil {
            head = node
            tail = node
        } else {
            tail?.next = node
            node.previous = tail
            tail = node
        }
    }
    
    func moveToHead(_ value: T) {
        guard let node = nodeMap[value] else { return }
        
        // Remove from current position
        if node === head {
            return // Already at head
        } else if node === tail {
            tail = node.previous
            tail?.next = nil
        } else {
            node.previous?.next = node.next
            node.next?.previous = node.previous
        }
        
        // Move to head
        node.previous = nil
        node.next = head
        head?.previous = node
        head = node
    }
    
    func remove(_ value: T) {
        guard let node = nodeMap[value] else { return }
        
        nodeMap.removeValue(forKey: value)
        
        if node === head && node === tail {
            head = nil
            tail = nil
        } else if node === head {
            head = node.next
            head?.previous = nil
        } else if node === tail {
            tail = node.previous
            tail?.next = nil
        } else {
            node.previous?.next = node.next
            node.next?.previous = node.previous
        }
    }
}

private class Node<T> {
    let value: T
    var next: Node<T>?
    var previous: Node<T>?
    
    init(value: T) {
        self.value = value
    }
}