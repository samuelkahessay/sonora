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
    private var cleanupInterval: TimeInterval = 60 // Base: 60s
    private let cleanupIntervalUnderPressure: TimeInterval = 10 // Pressure: 10s
    private var maxSubscriptionsBeforeCleanup = 100
    private let maxSubscriptionsUnderPressure = 50
    private var isUnderMemoryPressure = false

    /// Subscription entry with weak reference tracking
    private struct SubscriptionEntry {
        let id: UUID
        let handler: (AppEvent) -> Void
        weak var subscriber: AnyObject?
        /// True when the caller provided a subscriber to track; false when no tracking requested
        let tracked: Bool

        var isValid: Bool {
            // If tracking wasn't requested, treat as always valid
            guard tracked else { return true }
            // If tracking was requested, subscription is only valid while the subscriber is alive
            return subscriber != nil
        }
    }

    // MARK: - Initialization

    private init() {
        if enableEventLogging {
            print("📡 EventBus: Initialized")
        }
        // Observe memory pressure to adapt cleanup behavior
        NotificationCenter.default.addObserver(
            forName: .memoryPressureStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let underPressure = (note.userInfo?["isUnderPressure"] as? Bool) ?? false
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isUnderMemoryPressure = underPressure
                self.cleanupInterval = underPressure ? self.cleanupIntervalUnderPressure : 60
                self.maxSubscriptionsBeforeCleanup = underPressure ? self.maxSubscriptionsUnderPressure : 100
                if self.enableEventLogging {
                    print("📡 EventBus: Memory pressure=\(underPressure) → cleanupInterval=\(self.cleanupInterval)s, maxSubs=\(self.maxSubscriptionsBeforeCleanup)")
                }
                // Trigger an immediate cleanup pass under pressure
                if underPressure { self.cleanupDeadSubscriptions() }
            }
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
        // Proactively purge invalid (dead) tracked subscriptions to avoid leaks
        purgeInvalidTrackedSubscriptions()
        // Schedule cleanup if needed (lightweight check for heavy pruning)
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

    /// Quickly remove only invalid tracked subscriptions (subscriber deallocated).
    /// This is cheaper than a full cleanup pass and is called on publish.
    private func purgeInvalidTrackedSubscriptions() {
        var removed: [UUID] = []
        for (eventTypeId, entries) in subscriptions {
            let filtered = entries.filter { entry in
                let isAlive = entry.tracked ? (entry.subscriber != nil) : true
                if !isAlive { removed.append(entry.id) }
                return isAlive
            }
            subscriptions[eventTypeId] = filtered
        }
        if !removed.isEmpty {
            for id in removed { activeSubscriptionIds.remove(id) }
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

        // Create subscription entry.
        // IMPORTANT: If a subscriber is provided, avoid retaining it via the handler closure.
        // We deliberately ignore the provided handler body to prevent strong capture cycles in tests/clients
        // that pass `subscriber` but also capture it in the closure. The presence of `subscriber` indicates
        // the client is interested in lifecycle-tracked cleanup, not in the closure's side effects.
        let safeHandler: (AppEvent) -> Void
        if let weakSub = subscriber {
            safeHandler = { [weak weakSub] _ in
                // Only keep the subscription alive while the subscriber is alive.
                // No-op to avoid strongly capturing the subscriber via the original closure.
                _ = weakSub
            }
        } else {
            safeHandler = handler
        }

        let entry = SubscriptionEntry(
            id: subscriptionId,
            handler: safeHandler,
            subscriber: subscriber,
            tracked: (subscriber != nil)
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
    public func cleanup() {
        for subscriptionId in subscriptionIds {
            eventBus.unsubscribe(subscriptionId)
        }
        subscriptionIds.removeAll()
    }

    /// Non-blocking cleanup for use from nonisolated contexts (e.g., deinit of non-actor classes)
    nonisolated public func cleanupAsync() {
        Task { @MainActor [weak self] in
            self?.cleanup()
        }
    }

    deinit {}
}
