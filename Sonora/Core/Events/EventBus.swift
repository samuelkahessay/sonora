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
    
    /// Storage for event subscriptions grouped by event type
    /// Key: Event type identifier, Value: Array of (subscription ID, handler) pairs
    private var subscriptions: [ObjectIdentifier: [(UUID, (AppEvent) -> Void)]] = [:]
    
    /// Set of all active subscription IDs for validation
    private var activeSubscriptionIds: Set<UUID> = []
    
    /// Debug flag for logging event activity
    private let enableEventLogging = false
    
    // MARK: - Initialization
    
    private init() {
        if enableEventLogging {
            print("📡 EventBus: Initialized")
        }
    }
    
    // MARK: - Public Interface
    
    /// Publish an event to all subscribers
    /// - Parameter event: The event to publish
    public func publish(_ event: AppEvent) {
        if enableEventLogging {
            print("📡 EventBus: Publishing \(event.description)")
        }
        
        // Get the type identifier for the event
        let eventTypeId = ObjectIdentifier(AppEvent.self)
        
        // Find and execute all handlers for this event type
        guard let handlers = subscriptions[eventTypeId] else {
            if enableEventLogging {
                print("📡 EventBus: No subscribers for event type")
            }
            return
        }
        
        if enableEventLogging {
            print("📡 EventBus: Notifying \(handlers.count) subscribers")
        }
        
        // Execute all handlers for this event type
        for (subscriptionId, handler) in handlers {
            // Verify subscription is still active (safety check)
            guard activeSubscriptionIds.contains(subscriptionId) else {
                continue
            }
            
            // Execute handler (non-throwing)
            handler(event)
        }
    }
    
    /// Subscribe to events of a specific type
    /// - Parameters:
    ///   - eventType: The type of events to subscribe to (currently only AppEvent.self)
    ///   - handler: The closure to execute when events are published
    /// - Returns: Subscription ID that can be used to unsubscribe
    public func subscribe(
        to eventType: AppEvent.Type = AppEvent.self,
        handler: @escaping (AppEvent) -> Void
    ) -> UUID {
        let subscriptionId = UUID()
        let eventTypeId = ObjectIdentifier(eventType)
        
        // Initialize subscription array if needed
        if subscriptions[eventTypeId] == nil {
            subscriptions[eventTypeId] = []
        }
        
        // Add subscription
        subscriptions[eventTypeId]?.append((subscriptionId, handler))
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
            subscriptions[eventTypeId]?.removeAll { $0.0 == subscriptionId }
            
            // Clean up empty arrays
            if subscriptions[eventTypeId]?.isEmpty == true {
                subscriptions[eventTypeId] = nil
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
    func subscribe(to eventType: AppEvent.Type, handler: @escaping (AppEvent) -> Void) -> UUID
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
        let subscriptionId = eventBus.subscribe(to: eventType, handler: handler)
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
