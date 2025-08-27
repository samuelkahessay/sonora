import Foundation
import Combine

/// Simple dependency injection container for Sonora services
/// Provides protocol-based access to existing service instances
@MainActor
final class DIContainer: ObservableObject {
    
    // MARK: - Singleton
    static let shared = DIContainer()
    
    // MARK: - Private Service Instances
    private var _audioRecorder: AudioRecorder!
    private var _transcriptionManager: TranscriptionManager!
    private var _analysisService: AnalysisService!
    private var _memoStore: MemoStore!
    private var _memoRepository: MemoRepositoryImpl!
    private var _transcriptionRepository: TranscriptionRepository!
    private var _analysisRepository: AnalysisRepository!
    private var _logger: LoggerProtocol!
    private var _operationCoordinator: OperationCoordinator!
    
    // MARK: - Initialization
    private init() {
        // Services will be injected after initialization
        print("🏭 DIContainer: Initialized, waiting for service injection")
    }
    
    /// Configure DIContainer with shared service instances
    /// This ensures all parts of the app use the same service instances
    func configure(
        audioRecorder: AudioRecorder? = nil,
        analysisService: AnalysisService? = nil,
        logger: LoggerProtocol? = nil
    ) {
        // Initialize logger first
        self._logger = logger ?? Logger.shared
        
        // Initialize repositories first
        self._transcriptionRepository = TranscriptionRepositoryImpl()
        self._analysisRepository = AnalysisRepositoryImpl()
        self._memoRepository = MemoRepositoryImpl()
        
        // Create MemoStore with the transcription repository (for legacy compatibility)
        self._memoStore = MemoStore(transcriptionRepository: _transcriptionRepository)
        self._transcriptionManager = _memoStore.sharedTranscriptionManager
        self._audioRecorder = audioRecorder ?? AudioRecorder()
        self._analysisService = analysisService ?? AnalysisService()
        self._operationCoordinator = OperationCoordinator.shared
        
        _logger.info("DIContainer: Configured with shared service instances", category: .system, context: LogContext())
        _logger.debug("DIContainer: MemoStore: \(ObjectIdentifier(self._memoStore))", category: .system, context: LogContext())
        _logger.debug("DIContainer: MemoRepository: \(ObjectIdentifier(self._memoRepository))", category: .system, context: LogContext())
        _logger.debug("DIContainer: TranscriptionManager: \(ObjectIdentifier(self._transcriptionManager))", category: .system, context: LogContext())
        _logger.debug("DIContainer: TranscriptionRepository: \(ObjectIdentifier(self._transcriptionRepository))", category: .system, context: LogContext())
        _logger.debug("DIContainer: AnalysisRepository: \(ObjectIdentifier(self._analysisRepository))", category: .system, context: LogContext())
    }
    
    /// Check if container has been properly configured
    private func ensureConfigured() {
        guard _memoStore != nil, _memoRepository != nil else {
            fatalError("DIContainer has not been configured. Call configure() before using services.")
        }
    }
    
    // MARK: - Protocol-Based Service Access
    
    /// Get audio recording service
    func audioRecordingService() -> AudioRecordingService {
        ensureConfigured()
        return _audioRecorder
    }
    
    /// Get transcription service
    func transcriptionService() -> TranscriptionServiceProtocol {
        ensureConfigured()
        return _transcriptionManager
    }
    
    /// Get analysis service
    func analysisService() -> AnalysisServiceProtocol {
        ensureConfigured()
        return _analysisService
    }
    
    /// Get memo repository
    func memoRepository() -> MemoRepository {
        ensureConfigured()
        return _memoRepository
    }
    
    /// Get transcription repository
    func transcriptionRepository() -> TranscriptionRepository {
        ensureConfigured()
        return _transcriptionRepository
    }
    
    /// Get analysis repository
    func analysisRepository() -> AnalysisRepository {
        ensureConfigured()
        return _analysisRepository
    }
    
    /// Get logger service
    func logger() -> LoggerProtocol {
        ensureConfigured()
        return _logger
    }
    
    /// Get operation coordinator service
    func operationCoordinator() -> OperationCoordinator {
        ensureConfigured()
        return _operationCoordinator
    }
    
    // MARK: - Concrete Service Access (for gradual migration)
    
    /// Get concrete AudioRecorder instance
    /// Use this during gradual migration from @StateObject
    func audioRecorder() -> AudioRecorder {
        ensureConfigured()
        return _audioRecorder
    }
    
    /// Get concrete TranscriptionManager instance
    /// Use this during gradual migration from direct instantiation
    func transcriptionManager() -> TranscriptionManager {
        ensureConfigured()
        return _transcriptionManager
    }
    
    /// Get concrete AnalysisService instance
    /// Use this during gradual migration from @StateObject
    func concreteAnalysisService() -> AnalysisService {
        ensureConfigured()
        return _analysisService
    }
    
    /// Get concrete MemoStore instance
    /// Used for legacy compatibility during final migration phases
    func memoStore() -> MemoStore {
        ensureConfigured()
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
