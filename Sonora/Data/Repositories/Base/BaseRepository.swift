//
//  BaseRepository.swift
//  Sonora
//
//  Common repository patterns and CRUD operations
//  Provides shared functionality for data persistence and state management
//

import Foundation
import Combine

/// Base repository functionality for common CRUD operations and state management
/// Provides standardized patterns for data persistence, caching, and reactive updates
@MainActor
protocol BaseRepository: ObservableObject {
    
    // MARK: - Entity Type
    
    /// The primary entity type managed by this repository
    associatedtype Entity: Identifiable where Entity.ID == UUID
    
    /// The key type used for caching and lookups
    associatedtype CacheKey: Hashable = UUID
    
    // MARK: - Core CRUD Operations
    
    /// Save an entity to persistent storage
    /// - Parameter entity: The entity to save
    /// - Throws: RepositoryError if save fails
    func save(_ entity: Entity) throws
    
    /// Load an entity by its identifier
    /// - Parameter id: The entity identifier
    /// - Returns: The entity if found, nil otherwise
    func load(by id: Entity.ID) -> Entity?
    
    /// Delete an entity by its identifier  
    /// - Parameter id: The entity identifier
    /// - Throws: RepositoryError if deletion fails
    func delete(by id: Entity.ID) throws
    
    /// Load all entities
    /// - Returns: Array of all entities
    func loadAll() -> [Entity]
    
    /// Check if an entity exists
    /// - Parameter id: The entity identifier
    /// - Returns: True if entity exists, false otherwise
    func exists(id: Entity.ID) -> Bool
    
    // MARK: - Batch Operations
    
    /// Save multiple entities
    /// - Parameter entities: The entities to save
    /// - Throws: RepositoryError if any save fails
    func saveAll(_ entities: [Entity]) throws
    
    /// Delete multiple entities
    /// - Parameter ids: The entity identifiers to delete
    /// - Throws: RepositoryError if any deletion fails
    func deleteAll(ids: [Entity.ID]) throws
    
    // MARK: - Cache Management
    
    /// Clear all cached data
    func clearCache()
    
    /// Get cache size information
    /// - Returns: Number of cached items
    func getCacheSize() -> Int
    
    /// Refresh cache from persistent storage
    func refreshCache()
}

// MARK: - Default Implementations

extension BaseRepository {
    
    /// Default implementation for exists check
    func exists(id: Entity.ID) -> Bool {
        return load(by: id) != nil
    }
    
    /// Default batch save implementation
    func saveAll(_ entities: [Entity]) throws {
        for entity in entities {
            try save(entity)
        }
    }
    
    /// Default batch delete implementation
    func deleteAll(ids: [Entity.ID]) throws {
        for id in ids {
            try delete(by: id)
        }
    }
    
    /// Default cache size for repositories without specific caching
    func getCacheSize() -> Int {
        return loadAll().count
    }
}

// MARK: - File-based Repository Base

/// Base class for repositories that use file system storage
/// Provides common file operations and JSON persistence
@MainActor
open class FileBasedRepository<Entity: Codable & Identifiable>: ObservableObject 
where Entity.ID == UUID {
    
    // MARK: - Storage Properties
    
    /// The directory where entity files are stored
    internal let storageDirectory: URL
    
    /// In-memory cache for loaded entities
    internal var entityCache: [UUID: Entity] = [:]
    
    /// File manager instance
    internal let fileManager = FileManager.default
    
    /// JSON encoder for persistence
    internal let encoder: JSONEncoder
    
    /// JSON decoder for loading
    internal let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    public init(storageDirectory: URL, 
                encoder: JSONEncoder = JSONEncoder(),
                decoder: JSONDecoder = JSONDecoder()) {
        self.storageDirectory = storageDirectory
        self.encoder = encoder
        self.decoder = decoder
        
        // Create storage directory if it doesn't exist
        try? fileManager.createDirectory(at: storageDirectory, 
                                       withIntermediateDirectories: true)
    }
    
    // MARK: - File Operations
    
    /// Get the file URL for an entity
    /// - Parameter id: Entity identifier
    /// - Returns: File URL for the entity
    internal func fileURL(for id: UUID) -> URL {
        return storageDirectory.appendingPathComponent("\(id.uuidString).json")
    }
    
    /// Save entity to file
    /// - Parameter entity: Entity to save
    /// - Throws: RepositoryError if save fails
    internal func saveToFile(_ entity: Entity) throws {
        let url = fileURL(for: entity.id)
        let data = try encoder.encode(entity)
        try data.write(to: url)
        
        // Update cache
        entityCache[entity.id] = entity
        objectWillChange.send()
    }
    
    /// Load entity from file
    /// - Parameter id: Entity identifier
    /// - Returns: Entity if found, nil otherwise
    internal func loadFromFile(id: UUID) -> Entity? {
        // Check cache first
        if let cached = entityCache[id] {
            return cached
        }
        
        let url = fileURL(for: id)
        guard let data = try? Data(contentsOf: url),
              let entity = try? decoder.decode(Entity.self, from: data) else {
            return nil
        }
        
        // Cache the loaded entity
        entityCache[id] = entity
        return entity
    }
    
    /// Delete entity file
    /// - Parameter id: Entity identifier
    /// - Throws: RepositoryError if deletion fails
    internal func deleteFile(id: UUID) throws {
        let url = fileURL(for: id)
        try fileManager.removeItem(at: url)
        
        // Remove from cache
        entityCache.removeValue(forKey: id)
        objectWillChange.send()
    }
    
    /// Load all entity files
    /// - Returns: Array of all entities
    internal func loadAllFiles() -> [Entity] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil
        ).filter({ $0.pathExtension == "json" }) else {
            return []
        }
        
        return fileURLs.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let entity = try? decoder.decode(Entity.self, from: data) else {
                return nil
            }
            
            // Cache loaded entities
            entityCache[entity.id] = entity
            return entity
        }
    }
    
    /// Get all file URLs in storage directory
    /// - Returns: Array of JSON file URLs
    internal func getAllFileURLs() -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        
        return urls.filter { $0.pathExtension == "json" }
    }
}

// MARK: - BaseRepository Conformance for FileBasedRepository

extension FileBasedRepository: BaseRepository {
    
    public func save(_ entity: Entity) throws {
        try saveToFile(entity)
    }
    
    public func load(by id: UUID) -> Entity? {
        return loadFromFile(id: id)
    }
    
    public func delete(by id: UUID) throws {
        try deleteFile(id: id)
    }
    
    public func loadAll() -> [Entity] {
        return loadAllFiles()
    }
    
    public func clearCache() {
        entityCache.removeAll()
        objectWillChange.send()
    }
    
    public func getCacheSize() -> Int {
        return entityCache.count
    }
    
    public func refreshCache() {
        entityCache.removeAll()
        _ = loadAllFiles() // This will populate the cache
        objectWillChange.send()
    }
}

// MARK: - Repository Validation

/// Validation helpers for repository operations
public enum RepositoryValidation {
    
    /// Validate entity before save
    /// - Parameter entity: Entity to validate
    /// - Throws: RepositoryError if validation fails
    public static func validateForSave<T: Identifiable>(_ entity: T) throws where T.ID == UUID {
        // Basic validation - can be extended per repository
        if entity.id.uuidString.isEmpty {
            throw RepositoryError.validationFailed("Entity must have a valid ID")
        }
    }
    
    /// Validate ID for operations
    /// - Parameter id: ID to validate
    /// - Throws: RepositoryError if validation fails
    public static func validateID(_ id: UUID) throws {
        if id.uuidString.isEmpty {
            throw RepositoryError.validationFailed("ID cannot be empty")
        }
    }
}

// MARK: - Repository Metrics

/// Performance and usage metrics for repositories
public struct RepositoryMetrics {
    public let cacheHitRate: Double
    public let totalOperations: Int
    public let averageOperationTime: TimeInterval
    public let lastRefreshTime: Date?
    
    public init(cacheHitRate: Double = 0.0,
                totalOperations: Int = 0,
                averageOperationTime: TimeInterval = 0.0,
                lastRefreshTime: Date? = nil) {
        self.cacheHitRate = cacheHitRate
        self.totalOperations = totalOperations
        self.averageOperationTime = averageOperationTime
        self.lastRefreshTime = lastRefreshTime
    }
}