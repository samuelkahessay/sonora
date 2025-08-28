import Foundation
import Combine

// Simple dependency registration container
typealias ResolverType = DIContainer
@MainActor
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
    private var _transcriptionAPI: (any TranscriptionAPI)?
    private var _analysisService: AnalysisService!
    private var _memoRepository: MemoRepositoryImpl!
    private var _transcriptionRepository: (any TranscriptionRepository)?
    private var _analysisRepository: (any AnalysisRepository)?
    private var _logger: (any LoggerProtocol)?
    private var _operationCoordinator: (any OperationCoordinatorProtocol)!
    private var _backgroundAudioService: BackgroundAudioService!
    private var _audioRepository: (any AudioRepository)?
    private var _startRecordingUseCase: StartRecordingUseCase!
    private var _systemNavigator: (any SystemNavigator)?
    private var _liveActivityService: (any LiveActivityServiceProtocol)?
    
    // MARK: - Initialization
    private init() {
        // Services will be injected after initialization
        print("🏭 DIContainer: Initialized, waiting for service injection")
    }
    
    // MARK: - Configuration Guard
    private var isConfigured: Bool = false
    
    // MARK: - Registration Methods
    
    /// Register a service with a factory closure
    func register<T>(_ type: T.Type, factory: @escaping (any Resolver) -> T) {
        let key = ObjectIdentifier(type)
        registrations[key] = factory
    }
    
    /// Resolve a service from registrations
    func resolve<T>(_ type: T.Type) -> T? {
        let key = ObjectIdentifier(type)
        guard let factory = registrations[key] as? (any Resolver) -> T else {
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
        
        // Register SystemNavigator
        register((any SystemNavigator).self) { _ in
            return SystemNavigatorImpl() as any SystemNavigator
        }
        
        // Register AudioRepository 
        register((any AudioRepository).self) { resolver in
            let backgroundService = resolver.resolve(BackgroundAudioService.self)!
            return AudioRepositoryImpl(backgroundAudioService: backgroundService) as any AudioRepository
        }
        
        // Register StartRecordingUseCase (resolve coordinator directly to avoid early DI accessor)
        register(StartRecordingUseCase.self) { resolver in
            let audioRepository = resolver.resolve((any AudioRepository).self)!
            let coordinator: any OperationCoordinatorProtocol = OperationCoordinator.shared
            return StartRecordingUseCase(audioRepository: audioRepository, operationCoordinator: coordinator)
        }
        
        // Register LiveActivityService
        register((any LiveActivityServiceProtocol).self) { _ in
            return LiveActivityService() as any LiveActivityServiceProtocol
        }
    }
    
    /// Configure DIContainer with shared service instances
    /// This ensures all parts of the app use the same service instances
    func configure(
        analysisService: AnalysisService? = nil,
        logger: (any LoggerProtocol)? = nil
    ) {
        // Prevent re-entrant configuration
        if isConfigured { return }
        isConfigured = true
        // Initialize coordinator early to satisfy registrations that may resolve it
        self._operationCoordinator = OperationCoordinator.shared
        // Setup repositories first
        setupRepositories()
        
        // Initialize core infrastructure
        self._logger = logger ?? Logger.shared
        self._transcriptionRepository = TranscriptionRepositoryImpl()
        self._analysisRepository = AnalysisRepositoryImpl()
        
        // Initialize services from registrations
        self._backgroundAudioService = resolve(BackgroundAudioService.self)!
        self._audioRepository = resolve((any AudioRepository).self)!
        self._startRecordingUseCase = resolve(StartRecordingUseCase.self)!
        self._systemNavigator = resolve((any SystemNavigator).self)!
        self._liveActivityService = resolve((any LiveActivityServiceProtocol).self)!
        
        // Initialize external API services  
        self._transcriptionAPI = TranscriptionService()
        self._analysisService = analysisService ?? AnalysisService()
        // Coordinator already initialized above
        
        // Initialize MemoRepository with Use Case dependencies
        guard let trRepo = _transcriptionRepository, let trAPI = _transcriptionAPI else {
            fatalError("DIContainer not fully configured: missing transcription dependencies")
        }
        let startTranscriptionUseCase = StartTranscriptionUseCase(
            transcriptionRepository: trRepo,
            transcriptionAPI: trAPI,
            operationCoordinator: self._operationCoordinator
        )
        let getTranscriptionStateUseCase = GetTranscriptionStateUseCase(
            transcriptionRepository: trRepo
        )
        let retryTranscriptionUseCase = RetryTranscriptionUseCase(
            transcriptionRepository: trRepo,
            transcriptionAPI: trAPI
        )
        
        self._memoRepository = MemoRepositoryImpl(
            transcriptionRepository: trRepo,
            startTranscriptionUseCase: startTranscriptionUseCase,
            getTranscriptionStateUseCase: getTranscriptionStateUseCase,
            retryTranscriptionUseCase: retryTranscriptionUseCase
        )
        
        _logger?.info("DIContainer: Configured with shared service instances", category: .system, context: LogContext())
        _logger?.debug("DIContainer: MemoRepository: \(ObjectIdentifier(self._memoRepository))", category: .system, context: LogContext())
        if let repoObj = self._transcriptionRepository as? AnyObject {
            _logger?.debug("DIContainer: TranscriptionRepository: \(ObjectIdentifier(repoObj))", category: .system, context: LogContext())
        }
        if let analysisRepoObj = self._analysisRepository as? AnyObject {
            _logger?.debug("DIContainer: AnalysisRepository: \(ObjectIdentifier(analysisRepoObj))", category: .system, context: LogContext())
        }
    }
    
    /// Check if container has been properly configured
    private func ensureConfigured() {
        if !isConfigured {
            configure()
        }
    }
    
    // MARK: - Protocol-Based Service Access
    
    
    
    /// Get transcription API service
    func transcriptionAPI() -> any TranscriptionAPI {
        ensureConfigured()
        guard let api = _transcriptionAPI else { fatalError("DIContainer not configured: transcriptionAPI") }
        return api
    }
    
    /// Get analysis service
    func analysisService() -> any AnalysisServiceProtocol {
        ensureConfigured()
        return _analysisService
    }
    
    /// Get memo repository
    func memoRepository() -> any MemoRepository {
        ensureConfigured()
        return _memoRepository
    }
    
    /// Get transcription repository
    func transcriptionRepository() -> any TranscriptionRepository {
        ensureConfigured()
        guard let repo = _transcriptionRepository else { fatalError("DIContainer not configured: transcriptionRepository") }
        return repo
    }
    
    /// Get analysis repository
    func analysisRepository() -> any AnalysisRepository {
        ensureConfigured()
        guard let repo = _analysisRepository else { fatalError("DIContainer not configured: analysisRepository") }
        return repo
    }
    
    /// Get audio repository
    func audioRepository() -> any AudioRepository {
        ensureConfigured()
        guard let repo = _audioRepository else { fatalError("DIContainer not configured: audioRepository") }
        return repo
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
    
    /// Get system navigator
    func systemNavigator() -> any SystemNavigator {
        ensureConfigured()
        guard let nav = _systemNavigator else { fatalError("DIContainer not configured: systemNavigator") }
        return nav
    }
    
    /// Get logger service
    func logger() -> any LoggerProtocol {
        ensureConfigured()
        guard let logger = _logger else { fatalError("DIContainer not configured: logger") }
        return logger
    }
    
    /// Get operation coordinator service
    func operationCoordinator() -> any OperationCoordinatorProtocol {
        ensureConfigured()
        return _operationCoordinator
    }
    
    /// Get live activity service
    func liveActivityService() -> any LiveActivityServiceProtocol {
        ensureConfigured()
        guard let service = _liveActivityService else { fatalError("DIContainer not configured: liveActivityService") }
        return service
    }
    
}

// MARK: - SwiftUI Environment Support

import SwiftUI

/// Environment key for DIContainer
private struct DIContainerKey: EnvironmentKey {
    @MainActor static var defaultValue: DIContainer { DIContainer.shared }
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
    @MainActor
    func withDIContainer(_ container: DIContainer? = nil) -> some View {
        let resolved = container ?? DIContainer.shared
        return environment(\.diContainer, resolved)
    }
}
