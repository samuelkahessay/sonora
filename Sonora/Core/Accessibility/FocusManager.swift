import SwiftUI
import UIKit

/// Centralized focus management utility for accessibility
@MainActor
final class FocusManager {
    
    // MARK: - Shared Instance
    static let shared = FocusManager()
    
    private init() {}
    
    // MARK: - Focus Timing Constants
    
    /// Focus timing constants (kept nonisolated to avoid Swift 6 isolation issues)
    private enum FocusDelays {
        static let standard: TimeInterval = 0.3
        static let content: TimeInterval = 0.5
        static let quick: TimeInterval = 0.2
    }

    // Public, nonisolated accessors to delays for use from nonisolated contexts (e.g., SwiftUI modifiers)
    nonisolated static var standardDelay: TimeInterval { FocusDelays.standard }
    nonisolated static var contentDelay: TimeInterval { FocusDelays.content }
    nonisolated static var quickDelay: TimeInterval { FocusDelays.quick }
    
    // MARK: - Focus Management Methods
    
    /// Delays focus assignment to allow UI to settle
    /// - Parameters:
    ///   - delay: Time to wait before setting focus
    ///   - action: Focus assignment action to execute
    func delayedFocus(after delay: TimeInterval = FocusDelays.standard, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            action()
        }
    }
    
    /// Announces content changes to screen readers while preserving focus
    /// - Parameters:
    ///   - message: Message to announce
    ///   - priority: Announcement priority (default: .medium)
    func announceChange(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        UIAccessibility.post(notification: priority, argument: message)
    }
    
    /// Announces and focuses on new content
    /// - Parameters:
    ///   - message: Message to announce
    ///   - delay: Delay before focus assignment
    ///   - focusAction: Focus assignment action
    func announceAndFocus(
        _ message: String,
        delay: TimeInterval = FocusDelays.content,
        focusAction: @escaping () -> Void
    ) {
        announceChange(message)
        delayedFocus(after: delay, focusAction)
    }
    
    /// Sets focus on error states while announcing the error
    /// - Parameters:
    ///   - error: The error to announce
    ///   - focusAction: Optional focus action for error recovery
    func handleErrorFocus(_ error: Error, focusAction: (() -> Void)? = nil) {
        let message = "Error: \(error.localizedDescription)"
        announceChange(message, priority: .announcement)
        
        if let focusAction = focusAction {
            delayedFocus(after: FocusDelays.quick, focusAction)
        }
    }
    
    /// Manages focus for loading states
    /// - Parameters:
    ///   - isLoading: Whether content is loading
    ///   - loadingMessage: Message for loading state
    ///   - completedMessage: Message for completed state
    ///   - focusAction: Focus action when loading completes
    func handleLoadingFocus(
        isLoading: Bool,
        loadingMessage: String,
        completedMessage: String,
        focusAction: (() -> Void)? = nil
    ) {
        if isLoading {
            announceChange(loadingMessage)
        } else {
            announceChange(completedMessage)
            if let focusAction = focusAction {
                delayedFocus(after: FocusDelays.content, focusAction)
            }
        }
    }
    
    /// Sets initial focus when a view appears
    /// - Parameter focusAction: Focus assignment action
    func setInitialFocus(_ focusAction: @escaping () -> Void) {
        delayedFocus(after: FocusDelays.standard, focusAction)
    }
    
    /// Manages focus for tab/navigation changes
    /// - Parameter focusAction: Focus assignment action
    func handleNavigationFocus(_ focusAction: @escaping () -> Void) {
        delayedFocus(after: FocusDelays.standard, focusAction)
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    
    /// Sets initial focus when view appears with standard timing
    /// - Parameter focusAction: Focus assignment action
    func initialFocus(_ focusAction: @escaping () -> Void) -> some View {
        self.onAppear {
            FocusManager.shared.setInitialFocus(focusAction)
        }
    }
    
    /// Handles error announcements and optional focus
    /// - Parameters:
    ///   - error: Binding to error state
    ///   - focusAction: Optional focus action for error recovery
    func handleErrorFocus<E: Error & Equatable>(
        _ error: Binding<E?>,
        focusAction: (() -> Void)? = nil
    ) -> some View {
        self.onChange(of: error.wrappedValue) { _, newError in
            if let error = newError {
                FocusManager.shared.handleErrorFocus(error, focusAction: focusAction)
            }
        }
    }
    
    /// Manages focus for loading states
    /// - Parameters:
    ///   - isLoading: Binding to loading state
    ///   - loadingMessage: Message for loading state
    ///   - completedMessage: Message for completed state
    ///   - focusAction: Focus action when loading completes
    func handleLoadingFocus(
        _ isLoading: Binding<Bool>,
        loadingMessage: String,
        completedMessage: String,
        focusAction: (() -> Void)? = nil
    ) -> some View {
        self.onChange(of: isLoading.wrappedValue) { _, loading in
            FocusManager.shared.handleLoadingFocus(
                isLoading: loading,
                loadingMessage: loadingMessage,
                completedMessage: completedMessage,
                focusAction: focusAction
            )
        }
    }
}

// MARK: - Focus Priority Guidelines

/*
 Focus Priority Guidelines for Sonora:
 
 1. HIGH PRIORITY (Immediate focus):
    - Error states requiring user attention
    - Critical status changes (recording started/stopped)
    - Permission request outcomes
 
 2. MEDIUM PRIORITY (Standard delay):
    - New content appearing (transcription results)
    - Navigation between screens
    - Form field progression
 
 3. LOW PRIORITY (Content delay):
    - Complex content updates (analysis results)
    - Background process completions
    - Secondary information updates
 
 Focus Flow Patterns:
 
 1. Recording Flow:
    Initial: Record button → Recording: Status text → Completed: Record button
 
 2. Transcription Flow:
    Start: Transcribe button → Processing: Progress → Completed: Transcription text
 
 3. Analysis Flow:
    Start: Analysis button → Processing: Loading → Completed: Analysis results
 
 4. Navigation Flow:
    Page load: Primary content → Error: Error element → Recovery: Primary content
 
 5. Onboarding Flow:
    Page transition: Page content → Action: Primary button → Next: Page content
 */
