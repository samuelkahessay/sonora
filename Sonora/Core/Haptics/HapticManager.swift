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
    
    /// Play heavy impact feedback (important actions, confirmation dialogs)
    func playHeavyImpact() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
        print("💢 HapticManager: Heavy impact feedback")
    }
    
    /// Play custom impact feedback with specified intensity
    func playImpact(intensity: CGFloat) {
        guard isEnabled else { return }
        
        let clampedIntensity = max(0, min(1, intensity))
        
        if #available(iOS 13.0, *) {
            let customImpact = UIImpactFeedbackGenerator(style: .medium)
            customImpact.impactOccurred(intensity: clampedIntensity)
            print("🎯 HapticManager: Custom impact feedback (intensity: \(clampedIntensity))")
        } else {
            playMediumImpact()
        }
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
    
    /// Haptic feedback for navigation changes
    func playNavigationFeedback() {
        playSelection()
        print("🧭 HapticManager: Navigation feedback")
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
    
    // MARK: - Public Configuration
    
    /// Enable or disable haptic feedback
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        print("⚙️ HapticManager: Haptic feedback \(enabled ? "enabled" : "disabled")")
        
        if enabled {
            prepareGenerators()
        }
    }
    
    /// Prepare generators for upcoming use (call before anticipated feedback)
    func prepareForUse() {
        guard isEnabled else { return }
        prepareGenerators()
        print("🔧 HapticManager: Generators prepared")
    }
}

// MARK: - Convenience Extensions

extension HapticManager {
    
    /// Quick access methods for common patterns
    enum FeedbackType {
        case success
        case warning
        case error
        case selection
        case lightImpact
        case mediumImpact
        case heavyImpact
    }
    
    /// Play feedback by type
    func play(_ type: FeedbackType) {
        switch type {
        case .success:
            playSuccess()
        case .warning:
            playWarning()
        case .error:
            playError()
        case .selection:
            playSelection()
        case .lightImpact:
            playLightImpact()
        case .mediumImpact:
            playMediumImpact()
        case .heavyImpact:
            playHeavyImpact()
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension HapticManager {
    
    /// Test all haptic feedback types (for debugging)
    func testAllFeedback() {
        print("🧪 HapticManager: Testing all feedback types...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.playSuccess() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.playWarning() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.playError() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.playSelection() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.playLightImpact() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { self.playMediumImpact() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { self.playHeavyImpact() }
        
        print("🧪 HapticManager: Test sequence started")
    }
    
    /// Get debug information about haptic manager state
    var debugInfo: String {
        return """
        HapticManager Debug Info:
        - isEnabled: \(isEnabled)
        - generators prepared: true
        """
    }
}
#endif
