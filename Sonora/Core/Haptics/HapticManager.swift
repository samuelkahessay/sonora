import UIKit
import Foundation

/// Centralized haptic feedback management for accessibility and user experience
@MainActor
final class HapticManager {
    
    // MARK: - Singleton
    static let shared = HapticManager()
    
    // MARK: - Feedback Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Settings
    /// Whether haptic feedback is enabled (can be made user-configurable later)
    var isEnabled: Bool = true
    
    // MARK: - Initialization
    private init() {
        // Prepare generators for optimal responsiveness
        prepareGenerators()
        print("🔄 HapticManager: Initialized with prepared generators")
    }
    
    // MARK: - Public Methods
    
    /// Play success feedback (recording started/stopped, operation completed)
    func playSuccess() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
        print("✅ HapticManager: Success feedback")
    }
    
    /// Play warning feedback (errors, permission denied, validation failures)
    func playWarning() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
        print("⚠️ HapticManager: Warning feedback")
    }
    
    /// Play error feedback (critical failures, destructive actions)
    func playError() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
        print("❌ HapticManager: Error feedback")
    }
    
    /// Play selection feedback (tab changes, list selections, button taps)
    func playSelection() {
        guard isEnabled else { return }
        selectionFeedback.selectionChanged()
        print("🔘 HapticManager: Selection feedback")
    }
    
    /// Play light impact feedback (subtle interactions, confirmations)
    func playLightImpact() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
        print("💫 HapticManager: Light impact feedback")
    }
    
    /// Play medium impact feedback (button presses, moderate interactions)
    func playMediumImpact() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
        print("💥 HapticManager: Medium impact feedback")
    }
        
    // MARK: - Context-Specific Methods
    
    /// Haptic feedback for recording operations
    func playRecordingFeedback(isStarting: Bool) {
        if isStarting {
            playSuccess()
            print("🎤 HapticManager: Recording start feedback")
        } else {
            playMediumImpact()
            print("🛑 HapticManager: Recording stop feedback")
        }
    }
    
    /// Haptic feedback for deletion operations
    func playDeletionFeedback() {
        playError()
        print("🗑️ HapticManager: Deletion feedback")
    }
    
    /// Haptic feedback for transcription/analysis completion
    func playProcessingComplete() {
        playSuccess()
        print("🧠 HapticManager: Processing complete feedback")
    }
        
    /// Haptic feedback for permission granted
    func playPermissionGranted() {
        playSuccess()
        print("🔓 HapticManager: Permission granted feedback")
    }
    
    /// Haptic feedback for permission denied
    func playPermissionDenied() {
        playWarning()
        print("🔒 HapticManager: Permission denied feedback")
    }
    
    // MARK: - Private Methods
    
    private func prepareGenerators() {
        // Prepare generators for optimal performance
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
}

