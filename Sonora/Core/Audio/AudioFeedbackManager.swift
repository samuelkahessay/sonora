import Foundation
import AVFoundation

/// Centralized audio feedback management for accessibility and voice-first interactions
/// Provides audio cues to complement haptic feedback, especially useful for users
/// with haptics disabled or requiring auditory confirmation.
@MainActor
final class AudioFeedbackManager {

    // MARK: - Singleton
    static let shared = AudioFeedbackManager()

    // MARK: - Audio Players
    private var players: [AudioFeedbackType: AVAudioPlayer] = [:]

    // MARK: - Settings
    /// Whether audio feedback is enabled (can be made user-configurable later)
    var isEnabled: Bool = true

    // MARK: - Initialization
    private init() {
        setupAudioSession()
        preparePlayers()
        Logger.shared.debug("AudioFeedbackManager: Initialized",
                          category: .system)
    }

    // MARK: - Public Methods

    /// Play success tone (items added successfully, operations completed)
    func playSuccess() {
        guard isEnabled else { return }
        playTone(.success)
        Logger.shared.debug("AudioFeedbackManager: Success tone",
                          category: .system)
    }

    /// Play error tone (failed operations, critical failures)
    func playError() {
        guard isEnabled else { return }
        playTone(.error)
        Logger.shared.debug("AudioFeedbackManager: Error tone",
                          category: .system)
    }

    /// Play question tone (confirmation needed, ambiguous detection)
    func playQuestion() {
        guard isEnabled else { return }
        playTone(.question)
        Logger.shared.debug("AudioFeedbackManager: Question tone",
                          category: .system)
    }

    /// Play completion tone (batch operations finished)
    func playCompletion() {
        guard isEnabled else { return }
        playTone(.completion)
        Logger.shared.debug("AudioFeedbackManager: Completion tone",
                          category: .system)
    }

    // MARK: - Private Methods

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use ambient category to mix with other audio and not interrupt music
            try audioSession.setCategory(.ambient, mode: .default)
            try audioSession.setActive(true)
        } catch {
            Logger.shared.error("AudioFeedbackManager: Failed to setup audio session",
                              category: .system,
                              error: error)
        }
    }

    private func preparePlayers() {
        // Prepare system sounds for each feedback type
        // Using system sounds ensures compatibility and no resource loading
        AudioFeedbackType.allCases.forEach { type in
            _ = type.systemSoundID
            // System sounds don't need AVAudioPlayer preparation
            // They're ready to play immediately via AudioServicesPlaySystemSound
        }
    }

    private func playTone(_ type: AudioFeedbackType) {
        guard let soundID = type.systemSoundID else { return }

        // Use system sound services for immediate playback
        AudioServicesPlaySystemSound(soundID)
    }
}

// MARK: - Audio Feedback Types

enum AudioFeedbackType: CaseIterable {
    case success
    case error
    case question
    case completion

    /// System sound IDs for different feedback types
    /// These are standard iOS system sounds that don't require asset files
    var systemSoundID: SystemSoundID? {
        switch self {
        case .success:
            return 1054 // Acknowledgment sound (short ascending tone)
        case .error:
            return 1053 // Alert sound (short descending tone)
        case .question:
            return 1104 // Message sound (single tone)
        case .completion:
            return 1057 // New mail sound (ascending tone)
        }
    }
}
