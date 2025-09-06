import Foundation

// MARK: - DIContainer Audio Extensions

extension DIContainer {

    /// Get audio repository
    @MainActor
    func audioRepository() -> any AudioRepository {
        ensureConfigured()
        guard let repo = _audioRepository else { fatalError("DIContainer not configured: audioRepository") }
        return repo
    }

    /// Get background audio service
    @MainActor
    func backgroundAudioService() -> BackgroundAudioService {
        ensureConfigured()
        guard let service = _backgroundAudioService else {
            fatalError("DIContainer not configured: backgroundAudioService")
        }
        return service
    }

    // MARK: - Focused Audio Services

    /// Get audio session service
    @MainActor
    func audioSessionService() -> AudioSessionService {
        ensureConfigured()
        return resolve(AudioSessionService.self)!
    }

    /// Get audio recording service
    @MainActor
    func audioRecordingService() -> AudioRecordingService {
        ensureConfigured()
        return resolve(AudioRecordingService.self)!
    }

    /// Get background task service
    @MainActor
    func backgroundTaskService() -> BackgroundTaskService {
        ensureConfigured()
        return resolve(BackgroundTaskService.self)!
    }

    /// Get audio permission service
    @MainActor
    func audioPermissionService() -> AudioPermissionService {
        ensureConfigured()
        return resolve(AudioPermissionService.self)!
    }

    /// Get recording timer service
    @MainActor
    func recordingTimerService() -> RecordingTimerService {
        ensureConfigured()
        return resolve(RecordingTimerService.self)!
    }

    /// Get audio playback service
    @MainActor
    func audioPlaybackService() -> AudioPlaybackService {
        ensureConfigured()
        return resolve(AudioPlaybackService.self)!
    }
}

