import Foundation
import Combine

/// Simple dependency injection container for Sonora services
/// Provides protocol-based access to existing service instances
@MainActor
final class DIContainer: ObservableObject {
    
    // MARK: - Singleton
    static let shared = DIContainer()
    
    // MARK: - Private Service Instances
    private let _audioRecorder: AudioRecorder
    private let _transcriptionManager: TranscriptionManager
    private let _analysisService: AnalysisService
    private let _memoStore: MemoStore
    
    // MARK: - Initialization
    private init() {
        // Initialize services in the same way they're currently created
        self._memoStore = MemoStore()
        self._audioRecorder = AudioRecorder()
        self._transcriptionManager = TranscriptionManager()
        self._analysisService = AnalysisService()
        
        print("🏭 DIContainer: Initialized with all services")
    }
    
    // MARK: - Protocol-Based Service Access
    
    /// Get audio recording service
    func audioRecordingService() -> AudioRecordingService {
        return _audioRecorder
    }
    
    /// Get transcription service
    func transcriptionService() -> TranscriptionServiceProtocol {
        return _transcriptionManager
    }
    
    /// Get analysis service
    func analysisService() -> AnalysisServiceProtocol {
        return _analysisService
    }
    
    /// Get memo repository
    func memoRepository() -> MemoRepository {
        return _memoStore
    }
    
    // MARK: - Concrete Service Access (for gradual migration)
    
    /// Get concrete AudioRecorder instance
    /// Use this during gradual migration from @StateObject
    func audioRecorder() -> AudioRecorder {
        return _audioRecorder
    }
    
    /// Get concrete TranscriptionManager instance
    /// Use this during gradual migration from direct instantiation
    func transcriptionManager() -> TranscriptionManager {
        return _transcriptionManager
    }
    
    /// Get concrete AnalysisService instance
    /// Use this during gradual migration from @StateObject
    func concreteAnalysisService() -> AnalysisService {
        return _analysisService
    }
    
    /// Get concrete MemoStore instance
    /// Use this during gradual migration from @StateObject/@EnvironmentObject
    func memoStore() -> MemoStore {
        return _memoStore
    }
    
    // MARK: - Service Lifecycle Management
    
    /// Configure audio recorder callback
    /// This maintains the existing pattern used in RecordView
    func configureAudioRecorderCallback(_ callback: @escaping (URL) -> Void) {
        _audioRecorder.onRecordingFinished = callback
    }
    
    /// Get the shared transcription manager used by MemoStore
    /// This maintains the existing relationship between MemoStore and TranscriptionManager
    var sharedTranscriptionManager: TranscriptionManager {
        return _transcriptionManager
    }
    
    // MARK: - Container Information
    
    /// Check if container is properly initialized
    var isInitialized: Bool {
        return true // Always true since init() completes all setup
    }
    
    /// Get container status for debugging
    var containerStatus: String {
        return """
        DIContainer Status:
        - AudioRecorder: ✅ Initialized
        - TranscriptionManager: ✅ Initialized  
        - AnalysisService: ✅ Initialized
        - MemoStore: ✅ Initialized
        """
    }
}

// MARK: - SwiftUI Environment Support

import SwiftUI

/// Environment key for DIContainer
private struct DIContainerKey: EnvironmentKey {
    static let defaultValue = DIContainer.shared
}

extension EnvironmentValues {
    /// Access DIContainer through SwiftUI environment
    var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}

extension View {
    /// Inject DIContainer into SwiftUI environment
    func withDIContainer(_ container: DIContainer = .shared) -> some View {
        environment(\.diContainer, container)
    }
}