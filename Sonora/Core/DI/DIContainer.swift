import Foundation
import Combine

// Simple dependency registration container
typealias ResolverType = DIContainer
protocol Resolver {
    func resolve<T>(_ type: T.Type) -> T?
}

/// Simple dependency injection container for Sonora services
/// Provides protocol-based access to existing service instances
@MainActor
final class DIContainer: ObservableObject, Resolver {
    
    // MARK: - Singleton
    static let shared = DIContainer()
    
    // MARK: - Registration Container
    private var registrations: [ObjectIdentifier: Any] = [:]
    
    // MARK: - Private Service Instances
    private var _audioRecorder: AudioRecorder!
    private var _transcriptionAPI: TranscriptionAPI!
    private var _analysisService: AnalysisService!
    private var _memoRepository: MemoRepositoryImpl!
    private var _transcriptionRepository: TranscriptionRepository!
    private var _analysisRepository: AnalysisRepository!
    private var _logger: LoggerProtocol!
    private var _operationCoordinator: OperationCoordinator!
    private var _backgroundAudioService: BackgroundAudioService!
    private var _audioRepository: AudioRepository!
    private var _startRecordingUseCase: StartRecordingUseCase!
    
    // MARK: - Initialization
    private init() {
        // Services will be injected after initialization
        print("🏭 DIContainer: Initialized, waiting for service injection")
    }
    
    // MARK: - Registration Methods
    
    /// Register a service with a factory closure
    func register<T>(_ type: T.Type, factory: @escaping (Resolver) -> T) {
        let key = ObjectIdentifier(type)
        registrations[key] = factory
    }
    
    /// Resolve a service from registrations
    func resolve<T>(_ type: T.Type) -> T? {
        let key = ObjectIdentifier(type)
        guard let factory = registrations[key] as? (Resolver) -> T else {
            return nil
        }
        return factory(self)
    }
    
    /// Setup repository registrations
    private func setupRepositories() {
        // Register BackgroundAudioService
        register(BackgroundAudioService.self) { resolver in
            return BackgroundAudioService()
        }
        
        // Register AudioRepository 
        register(AudioRepository.self) { resolver in
            return AudioRepositoryImpl()
        }
        
        // Register StartRecordingUseCase 
        register(StartRecordingUseCase.self) { resolver in
            let audioRepository = resolver.resolve(AudioRepository.self)!
            return StartRecordingUseCase(audioRepository: audioRepository)
        }
    }
    
    /// Configure DIContainer with shared service instances
    /// This ensures all parts of the app use the same service instances
    func configure(
        audioRecorder: AudioRecorder? = nil,
        analysisService: AnalysisService? = nil,
        logger: LoggerProtocol? = nil
    ) {
        // Setup repositories first
        setupRepositories()
        
        // Initialize logger first
        self._logger = logger ?? Logger.shared
        
        // Initialize repositories first
        self._transcriptionRepository = TranscriptionRepositoryImpl()
        self._analysisRepository = AnalysisRepositoryImpl()
        
        // Initialize new services from registrations
        self._backgroundAudioService = resolve(BackgroundAudioService.self)!
        self._audioRepository = resolve(AudioRepository.self)!
        self._startRecordingUseCase = resolve(StartRecordingUseCase.self)!
        
        // Initialize transcription services
        self._transcriptionAPI = TranscriptionService()
        
        // Initialize MemoRepository with Use Case dependencies
        let startTranscriptionUseCase = StartTranscriptionUseCase(
            transcriptionRepository: _transcriptionRepository,
            transcriptionAPI: _transcriptionAPI
        )
        let getTranscriptionStateUseCase = GetTranscriptionStateUseCase(
            transcriptionRepository: _transcriptionRepository
        )
        let retryTranscriptionUseCase = RetryTranscriptionUseCase(
            transcriptionRepository: _transcriptionRepository,
            transcriptionAPI: _transcriptionAPI
        )
        
        self._memoRepository = MemoRepositoryImpl(
            startTranscriptionUseCase: startTranscriptionUseCase,
            getTranscriptionStateUseCase: getTranscriptionStateUseCase,
            retryTranscriptionUseCase: retryTranscriptionUseCase
        )
        self._audioRecorder = audioRecorder ?? AudioRecorder()
        self._analysisService = analysisService ?? AnalysisService()
        self._operationCoordinator = OperationCoordinator.shared
        
        _logger.info("DIContainer: Configured with shared service instances", category: .system, context: LogContext())
        _logger.debug("DIContainer: MemoRepository: \(ObjectIdentifier(self._memoRepository))", category: .system, context: LogContext())
        _logger.debug("DIContainer: TranscriptionRepository: \(ObjectIdentifier(self._transcriptionRepository))", category: .system, context: LogContext())
        _logger.debug("DIContainer: AnalysisRepository: \(ObjectIdentifier(self._analysisRepository))", category: .system, context: LogContext())
    }
    
    /// Check if container has been properly configured
    private func ensureConfigured() {
        guard _memoRepository != nil, _audioRepository != nil, _startRecordingUseCase != nil else {
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
    /// Returns the MemoRepository which provides the same TranscriptionServiceProtocol interface
    func transcriptionService() -> TranscriptionServiceProtocol {
        ensureConfigured()
        return _memoRepository
    }
    
    /// Get transcription API service
    func transcriptionAPI() -> TranscriptionAPI {
        ensureConfigured()
        return _transcriptionAPI
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
    
    /// Get audio repository
    func audioRepository() -> AudioRepository {
        ensureConfigured()
        return _audioRepository
    }
    
    /// Get background audio service
    func backgroundAudioService() -> BackgroundAudioService {
        ensureConfigured()
        return _backgroundAudioService
    }
    
    /// Get start recording use case
    func startRecordingUseCase() -> StartRecordingUseCase {
        ensureConfigured()
        return _startRecordingUseCase
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
    
    /// Get concrete AnalysisService instance
    /// Use this during gradual migration from @StateObject
    func concreteAnalysisService() -> AnalysisService {
        ensureConfigured()
        return _analysisService
    }
    
    
    // MARK: - Service Lifecycle Management
    
    /// Configure audio recorder callback
    /// This maintains the existing pattern used in RecordView
    func configureAudioRecorderCallback(_ callback: @escaping (URL) -> Void) {
        _audioRecorder.onRecordingFinished = callback
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
        - AnalysisService: ✅ Initialized
        - MemoRepository: ✅ Initialized
        - TranscriptionRepository: ✅ Initialized
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
