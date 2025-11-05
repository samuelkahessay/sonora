//
//  AppDelegate.swift
//  Sonora
//
//  Created to handle background URLSession completion events
//

import UIKit

/// App Delegate to handle UIKit lifecycle events, particularly background URLSession completions
///
/// This class is essential for background transcription to work properly when the phone is locked.
/// When a background URLSession completes (e.g., transcription upload/download), iOS needs a way
/// to wake the app and notify it. Without this delegate method, the app stays suspended and
/// transcription appears "stuck" until the user manually opens the app.
class AppDelegate: NSObject, UIApplicationDelegate {

    private let logger: any LoggerProtocol = Logger.shared

    /// Stores completion handlers for background URL session events, keyed by session identifier
    ///
    /// iOS provides a completion handler when waking the app for background session events.
    /// We store it here (keyed by session identifier) and call it later when URLSession delegate's
    /// `urlSessionDidFinishEvents(forBackgroundURLSession:)` method fires.
    /// This tells iOS that we're done processing and it can suspend the app again.
    ///
    /// Multiple sessions are supported:
    /// - `*.transcription.background` - Transcription service
    /// - `*.analysis.background` - Analysis service
    var backgroundSessionCompletionHandlers: [String: () -> Void] = [:]

    /// Called by iOS when a background URLSession has events to deliver
    ///
    /// This method is the critical piece for background transcription:
    /// 1. App goes to background while transcription is uploading/processing
    /// 2. URLSession continues working in background (separate daemon process)
    /// 3. Server responds with transcription result
    /// 4. iOS wakes/relaunches the app by calling this method
    /// 5. We store the completion handler
    /// 6. URLSession delivers events to our delegate
    /// 7. When all events are processed, delegate calls our stored completion handler
    /// 8. iOS knows we're done and can manage the app lifecycle appropriately
    ///
    /// - Parameters:
    ///   - application: The singleton app instance
    ///   - identifier: The identifier of the URLSession that has events (matches our background session ID)
    ///   - completionHandler: Completion handler to call when we're done processing events
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        logger.info("📱 Background URLSession completion handler called for session: \(identifier)", category: .system, context: nil)

        // Store the completion handler for this specific session
        // The corresponding URLSession delegate will call this when it finishes processing
        backgroundSessionCompletionHandlers[identifier] = completionHandler

        logger.debug("Stored completion handler for session: \(identifier)", category: .system, context: nil)
    }
}
