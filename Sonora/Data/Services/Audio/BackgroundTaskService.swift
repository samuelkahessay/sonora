//
//  BackgroundTaskService.swift
//  Sonora
//
//  Background task management service for audio recording
//  Handles iOS background task lifecycle to continue recording when app enters background
//

import Foundation
import UIKit
import Combine

/// Protocol defining background task management operations
@MainActor
protocol BackgroundTaskServiceProtocol: ObservableObject {
    var isBackgroundTaskActive: Bool { get }
    var backgroundTaskActivePublisher: AnyPublisher<Bool, Never> { get }
    
    func beginBackgroundTask() -> Bool
    func endBackgroundTask()
    func handleAppDidEnterBackground()
    func handleAppWillEnterForeground()
    
    // Callbacks
    var onBackgroundTaskExpired: (() -> Void)? { get set }
}

/// Focused service for iOS background task management during recording
@MainActor
final class BackgroundTaskService: NSObject, BackgroundTaskServiceProtocol, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published var isBackgroundTaskActive = false
    
    // MARK: - Publishers
    var backgroundTaskActivePublisher: AnyPublisher<Bool, Never> {
        $isBackgroundTaskActive.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Callbacks
    var onBackgroundTaskExpired: (() -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupNotificationObservers()
        print("🔄 BackgroundTaskService: Initialized")
    }
    
    deinit {
        // Note: We don't call UIApplication.shared.endBackgroundTask in deinit
        // because it requires main actor access. If a background task is still
        // active during service deallocation, the system will handle cleanup.
        NotificationCenter.default.removeObserver(self)
        print("🔄 BackgroundTaskService: Deinitialized")
    }
    
    // MARK: - Public Interface
    
    /// Begins a background task to allow operations to continue when app enters background
    @discardableResult
    func beginBackgroundTask() -> Bool {
        guard backgroundTaskIdentifier == .invalid else {
            print("🔄 BackgroundTaskService: Background task already active")
            return true
        }
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "AudioRecording") { [weak self] in
            print("⏰ BackgroundTaskService: Background task expired, cleaning up...")
            Task { @MainActor in
                self?.handleBackgroundTaskExpiration()
            }
        }
        
        let success = backgroundTaskIdentifier != .invalid
        
        if success {
            self.isBackgroundTaskActive = true
            print("🔄 BackgroundTaskService: Background task started (ID: \(backgroundTaskIdentifier.rawValue))")
        } else {
            print("❌ BackgroundTaskService: Failed to start background task")
        }
        
        return success
    }
    
    /// Ends the current background task
    func endBackgroundTask() {
        guard backgroundTaskIdentifier != .invalid else {
            return
        }
        
        print("🔄 BackgroundTaskService: Ending background task (ID: \(backgroundTaskIdentifier.rawValue))")
        
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
        self.isBackgroundTaskActive = false
    }
    
    /// Handles app entering background state
    func handleAppDidEnterBackground() {
        print("📱 BackgroundTaskService: App did enter background")
        
        // Background task should already be active for recording operations
        if !isBackgroundTaskActive {
            print("⚠️ BackgroundTaskService: No background task active when entering background")
        }
    }
    
    /// Handles app entering foreground state
    func handleAppWillEnterForeground() {
        print("📱 BackgroundTaskService: App will enter foreground")
        
        // Keep background task active in case user backgrounds the app again during recording
        if isBackgroundTaskActive {
            print("ℹ️ BackgroundTaskService: Background task remains active for continued recording")
        }
    }
    
    // removed unused helpers for remaining time and availability
    
    // MARK: - Private Methods
    
    /// Handles background task expiration
    private func handleBackgroundTaskExpiration() {
        print("⏰ BackgroundTaskService: Background task expired")
        
        // Notify delegate about expiration
        onBackgroundTaskExpired?()
        
        // Clean up background task
        endBackgroundTask()
    }
    
    /// Sets up notification observers for app lifecycle events
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackgroundNotification),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForegroundNotification),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidEnterBackgroundNotification() {
        // NotificationCenter calls this from a background thread, so we need to dispatch to MainActor
        Task { @MainActor in
            self.handleAppDidEnterBackground()
        }
    }
    
    @objc private func handleAppWillEnterForegroundNotification() {
        // NotificationCenter calls this from a background thread, so we need to dispatch to MainActor
        Task { @MainActor in
            self.handleAppWillEnterForeground()
        }
    }
}

// MARK: - Error Types

enum BackgroundTaskError: LocalizedError {
    case taskCreationFailed
    case taskExpired
    case backgroundRefreshDisabled
    
    var errorDescription: String? {
        switch self {
        case .taskCreationFailed:
            return "Failed to create background task"
        case .taskExpired:
            return "Background task expired"
        case .backgroundRefreshDisabled:
            return "Background refresh is disabled for this app"
        }
    }
}
