//
//  AppDelegate.swift
//  Sonora
//
//  Handles background URLSession completion events for transcription and analysis services.
//  When the phone is locked and background URLSession tasks complete, iOS wakes the app
//  and calls handleEventsForBackgroundURLSession to notify the appropriate service.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger: any LoggerProtocol = Logger.shared

    /// Stores completion handlers for background URLSessions
    /// Key: session identifier (e.g., "com.samuelkahessay.Sonora.transcription.background")
    /// Value: completion handler to call when session finishes
    private var backgroundCompletionHandlers: [String: () -> Void] = [:]

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        logger.debug(
            "AppDelegate: Background URLSession event for identifier: \(identifier)",
            category: .network,
            context: nil
        )

        // Store the completion handler - the URLSession will call it when done
        backgroundCompletionHandlers[identifier] = completionHandler

        // The URLSession for this identifier will automatically receive the pending events
        // and call urlSessionDidFinishEvents(forBackgroundURLSession:) on its delegate
        // At that point, the delegate should call notifyBackgroundSessionCompleted(identifier:)
    }

    /// Called by URLSessionDelegate when background session finishes processing events
    /// This triggers the stored completion handler to tell iOS we're done
    func notifyBackgroundSessionCompleted(identifier: String) {
        logger.debug(
            "AppDelegate: Background URLSession completed: \(identifier)",
            category: .network,
            context: nil
        )

        // Call the completion handler on main thread as required by iOS
        DispatchQueue.main.async { [weak self] in
            if let handler = self?.backgroundCompletionHandlers.removeValue(forKey: identifier) {
                self?.logger.debug(
                    "AppDelegate: Calling completion handler for: \(identifier)",
                    category: .network,
                    context: nil
                )
                handler()
            } else {
                self?.logger.warning(
                    "AppDelegate: No completion handler found for: \(identifier)",
                    category: .network,
                    context: nil,
                    error: nil
                )
            }
        }
    }
}
