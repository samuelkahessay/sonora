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
}
