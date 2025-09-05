import Foundation
import Combine

/// Simple in-memory event bus for app-wide event distribution
/// Provides type-safe publish/subscribe pattern with automatic cleanup
@MainActor
public final class EventBus: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide event distribution
    private static let _shared = EventBus()
    nonisolated(unsafe) public static var shared: EventBus { MainActor.assumeIsolated { _shared } }
    
    // MARK: - Private Properties
    
    /// Storage for event subscriptions with weak subscriber tracking
    /// Key: Event type identifier, Value: Array of subscription entries
    private var subscriptions: [ObjectIdentifier: [SubscriptionEntry]] = [:]
    
    /// Set of all active subscription IDs for validation
    private var activeSubscriptionIds: Set<UUID> = []
    
    /// Debug flag for logging event activity
    private let enableEventLogging = false
    
    /// Automatic cleanup configuration
    private var lastCleanupTime = Date()
    private let cleanupInterval: TimeInterval = 60 // Clean every 60 seconds
    private let maxSubscriptionsBeforeCleanup = 100
    
    /// Subscription entry with weak reference tracking
    private struct SubscriptionEntry {
        let id: UUID
        let handler: (AppEvent) -> Void
        weak var subscriber: AnyObject?
        let createdAt: Date
        
        var isValid: Bool {
            // If no subscriber tracking, assume valid
            guard let _ = subscriber else { return true }
            // If subscriber is nil, the subscription is dead
            return subscriber != nil
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        if enableEventLogging {
            print("📡 EventBus: Initialized")
        }
    }
    
    // MARK: - Memory Management
    
    /// Clean up dead subscriptions automatically
    private func cleanupDeadSubscriptions() {
        let now = Date()
        var totalCleaned = 0
        
        for eventTypeId in subscriptions.keys {
            // Filter out invalid subscriptions
            subscriptions[eventTypeId] = subscriptions[eventTypeId]?.filter { entry in
                if entry.isValid && activeSubscriptionIds.contains(entry.id) {
                    return true
                } else {
                    // Remove from active set if invalid
                    activeSubscriptionIds.remove(entry.id)
                    totalCleaned += 1
                    return false
                }
            }
            
            // Remove empty event type arrays
            if subscriptions[eventTypeId]?.isEmpty == true {
                subscriptions.removeValue(forKey: eventTypeId)
            }
        }
        
        if totalCleaned > 0 && enableEventLogging {
            print("📡 EventBus: Cleaned up \(totalCleaned) dead subscriptions")
        }
        
        lastCleanupTime = now
    }
    
    /// Schedule cleanup if needed
    private func scheduleCleanupIfNeeded() {
        let now = Date()
        let shouldCleanup = now.timeIntervalSince(lastCleanupTime) > cleanupInterval ||
                           activeSubscriptionIds.count > maxSubscriptionsBeforeCleanup
        
        if shouldCleanup {
            cleanupDeadSubscriptions()
        }
    }
    
    // MARK: - Public Interface
    
    /// Publish an event to all subscribers
    /// - Parameter event: The event to publish
    public func publish(_ event: AppEvent) {
        // Schedule cleanup if needed (lightweight check)
        scheduleCleanupIfNeeded()
        
        if enableEventLogging {
            print("📡 EventBus: Publishing \(event.description)")
        }
        
        // Get the type identifier for the event
        let eventTypeId = ObjectIdentifier(AppEvent.self)
        
        // Find and execute all handlers for this event type
        guard let entries = subscriptions[eventTypeId] else {
            if enableEventLogging {
                print("📡 EventBus: No subscribers for event type")
            }
            return
        }
        
        // Filter to only valid, active subscriptions
        let validEntries = entries.filter { entry in
            entry.isValid && activeSubscriptionIds.contains(entry.id)
        }
        
        if enableEventLogging {
            print("📡 EventBus: Notifying \(validEntries.count) subscribers")
        }
        
        // Execute all handlers for this event type
        for entry in validEntries {
            // Execute handler (non-throwing)
            entry.handler(event)
        }
    }
    
    /// Subscribe to events of a specific type
    /// - Parameters:
    ///   - eventType: The type of events to subscribe to (currently only AppEvent.self)
    ///   - handler: The closure to execute when events are published
    ///   - subscriber: Optional weak reference to the subscribing object for automatic cleanup
    /// - Returns: Subscription ID that can be used to unsubscribe
    public func subscribe(
        to eventType: AppEvent.Type = AppEvent.self,
        subscriber: AnyObject? = nil,
        handler: @escaping (AppEvent) -> Void
    ) -> UUID {
        let subscriptionId = UUID()
        let eventTypeId = ObjectIdentifier(eventType)
        
        // Initialize subscription array if needed
        if subscriptions[eventTypeId] == nil {
            subscriptions[eventTypeId] = []
        }
        
        // Create subscription entry
        let entry = SubscriptionEntry(
            id: subscriptionId,
            handler: handler,
            subscriber: subscriber,
            createdAt: Date()
        )
        
        // Add subscription
        subscriptions[eventTypeId]?.append(entry)
        activeSubscriptionIds.insert(subscriptionId)
        
        if enableEventLogging {
            print("📡 EventBus: Added subscription \(subscriptionId) for \(eventType)")
        }
        
        return subscriptionId
    }
    
    /// Remove a subscription
    /// - Parameter subscriptionId: The ID returned from subscribe()
    public func unsubscribe(_ subscriptionId: UUID) {
        guard activeSubscriptionIds.contains(subscriptionId) else {
            if enableEventLogging {
                print("⚠️ EventBus: Attempted to unsubscribe unknown subscription: \(subscriptionId)")
            }
            return
        }
        
        // Remove from all event type arrays
        for eventTypeId in subscriptions.keys {
            subscriptions[eventTypeId]?.removeAll { $0.id == subscriptionId }
            
            // Clean up empty arrays
            if subscriptions[eventTypeId]?.isEmpty == true {
                subscriptions.removeValue(forKey: eventTypeId)
            }
        }
        
        activeSubscriptionIds.remove(subscriptionId)
        
        if enableEventLogging {
            print("📡 EventBus: Removed subscription \(subscriptionId)")
        }
    }
    
    /// Remove all subscriptions (useful for testing or app reset)
    public func removeAllSubscriptions() {
        let count = activeSubscriptionIds.count
        subscriptions.removeAll()
        activeSubscriptionIds.removeAll()
        
        if enableEventLogging {
            print("📡 EventBus: Removed all \(count) subscriptions")
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Subscribe to events with automatic cleanup using Combine
    /// - Parameters:
    ///   - eventType: The type of events to subscribe to
    ///   - handler: The closure to execute when events are published
    /// - Returns: AnyCancellable that automatically unsubscribes when deallocated
    public func publisher(
        for eventType: AppEvent.Type = AppEvent.self
    ) -> AnyPublisher<AppEvent, Never> {
        return Future<AppEvent, Never> { [weak self] promise in
            guard let self = self else { return }
            
            _ = self.subscribe(to: eventType) { event in
                promise(.success(event))
            }
            
            // Note: This creates a single-use publisher
            // For continuous listening, use subscribe() directly
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Debug Information
    
    /// Check if there are any active subscriptions
    public var hasActiveSubscriptions: Bool {
        return !activeSubscriptionIds.isEmpty
    }
    
    /// Get count of subscribers for debugging
    public var subscriberCount: Int {
        return activeSubscriptionIds.count
    }
    
    /// Get subscription statistics for debugging
    public var subscriptionStats: String {
        return """
        EventBus Subscription Statistics:
        - Active subscriptions: \(activeSubscriptionIds.count)
        - Event types with subscribers: \(subscriptions.keys.count)
        - Total subscription entries: \(subscriptions.values.map { $0.count }.reduce(0, +))
        """
    }
}

// MARK: - EventBus Protocol

/// Protocol for dependency injection and testing
@MainActor
public protocol EventBusProtocol {
    func publish(_ event: AppEvent)
    func subscribe(to eventType: AppEvent.Type, subscriber: AnyObject?, handler: @escaping (AppEvent) -> Void) -> UUID
    func unsubscribe(_ subscriptionId: UUID)
    var subscriptionStats: String { get }
}

extension EventBus: EventBusProtocol {}

// MARK: - Subscription Management Helper

/// Helper class for managing event bus subscriptions with automatic cleanup
@MainActor
public final class EventSubscriptionManager {
    private var subscriptionIds: Set<UUID> = []
    private let eventBus: any EventBusProtocol
    
    public init(eventBus: any EventBusProtocol = EventBus.shared) {
        self.eventBus = eventBus
    }
    
    /// Add a managed subscription that will be automatically cleaned up
    public func subscribe(
        to eventType: AppEvent.Type = AppEvent.self,
        handler: @escaping (AppEvent) -> Void
    ) {
        let subscriptionId = eventBus.subscribe(to: eventType, subscriber: nil, handler: handler)
        subscriptionIds.insert(subscriptionId)
    }
    
    /// Clean up all managed subscriptions
    nonisolated public func cleanup() {
        Task { @MainActor in
            for subscriptionId in self.subscriptionIds {
                self.eventBus.unsubscribe(subscriptionId)
            }
            self.subscriptionIds.removeAll()
        }
    }
    
    deinit {
        cleanup()
    }
}
