import Foundation
import Combine
import SwiftData

// Simple dependency registration container
typealias ResolverType = DIContainer
protocol Resolver {
    func resolve<T>(_ type: T.Type) -> T?
}

/// Simple dependency injection container for Sonora services
/// Provides protocol-based access to existing service instances
final class DIContainer: ObservableObject, Resolver {
    
    // MARK: - Singleton
    static let shared = DIContainer()
    
    // MARK: - Registration Container
    private var registrations: [ObjectIdentifier: Any] = [:]
    
    // MARK: - Private Service Instances (Selective Memory Management)
    // Protocol types cannot use weak references, so we use a hybrid approach:
    // - Concrete class types: weak references where beneficial
    // - Protocol types: keep as optional strong references with lifecycle tracking
    private var _transcriptionAPI: (any TranscriptionAPI)?
    private var _transcriptionServiceFactory: TranscriptionServiceFactory?
    private var _modelDownloadManager: ModelDownloadManager?
    private var _analysisService: AnalysisService?
    private var _localAnalysisService: LocalAnalysisService?
    private var _memoRepository: MemoRepositoryImpl?
    private var _transcriptionRepository: (any TranscriptionRepository)?
    private var _analysisRepository: (any AnalysisRepository)?
    private var _logger: (any LoggerProtocol)?
    private var _backgroundAudioService: BackgroundAudioService?
    private var _audioRepository: (any AudioRepository)?
    private var _transcriptExporter: (any TranscriptExporting)?
    private var _analysisExporter: (any AnalysisExporting)?
    private var _startRecordingUseCase: StartRecordingUseCase?
    private var _startTranscriptionUseCase: (any StartTranscriptionUseCaseProtocol)?
    private var _systemNavigator: (any SystemNavigator)?
    private var _liveActivityService: (any LiveActivityServiceProtocol)?
    private var _eventBus: (any EventBusProtocol)?
    private var _eventHandlerRegistry: (any EventHandlerRegistryProtocol)?
    private var _moderationService: (any ModerationServiceProtocol)?
    private var _spotlightIndexer: (any SpotlightIndexing)?
    private var _whisperKitModelProvider: WhisperKitModelProvider?
    private var _modelContext: ModelContext? // Keep strong reference to ModelContext

    // MARK: - Phase 2: Core Optimization Services
    private var _audioQualityManager: AudioQualityManager?
    private var _whisperKitModelManager: WhisperKitModelManager?
    private var _memoryPressureDetector: MemoryPressureDetector?
    
    // MARK: - EventKit Services (Protocol References)
    private var _eventKitRepository: (any EventKitRepository)?
    private var _eventKitPermissionService: (any EventKitPermissionServiceProtocol)?
    private var _createCalendarEventUseCase: (any CreateCalendarEventUseCaseProtocol)?
    private var _createReminderUseCase: (any CreateReminderUseCaseProtocol)?
    private var _detectEventsAndRemindersUseCase: (any DetectEventsAndRemindersUseCaseProtocol)?
    
    // MARK: - Core Services (Strong References)
    // These services need to stay alive for the app lifetime
    private var _operationCoordinator: (any OperationCoordinatorProtocol)!
    
    // MARK: - Service Lifecycle Management
    private var serviceAccessTimes: [String: Date] = [:]
    private let serviceCleanupInterval: TimeInterval = 300 // 5 minutes
    private var lastCleanupTime = Date()
    
    // MARK: - Initialization
    private init() {
        // Services will be injected after initialization
        print("🏭 DIContainer: Initialized, waiting for service injection")
    }
    
    // MARK: - Configuration Guard
    private var isConfigured: Bool = false
    
    // MARK: - Memory Management
    
    /// Track service access for lifecycle management
    private func trackServiceAccess(_ serviceName: String) {
        serviceAccessTimes[serviceName] = Date()
        scheduleCleanupIfNeeded()
    }
    
    /// Schedule cleanup if needed based on memory pressure
    private func scheduleCleanupIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastCleanupTime) > serviceCleanupInterval else { return }
        
        Task.detached(priority: .utility) { [weak self] in
            await self?.performMemoryCleanup()
        }
    }
    
    /// Perform memory cleanup based on access patterns and system state
    @MainActor
    private func performMemoryCleanup() {
        let now = Date()
        lastCleanupTime = now
        
        // Check system memory pressure
        let memoryPressure = ProcessInfo.processInfo.thermalState
        let aggressiveCleanup = memoryPressure != .nominal
        let cleanupThreshold: TimeInterval = aggressiveCleanup ? 120 : serviceCleanupInterval
        
        var cleanedServices: [String] = []
        
        // Clean up unused services based on access time
        for (serviceName, lastAccess) in serviceAccessTimes {
            if now.timeIntervalSince(lastAccess) > cleanupThreshold {
                // Note: Weak references automatically nil out when service is deallocated
                serviceAccessTimes.removeValue(forKey: serviceName)
                cleanedServices.append(serviceName)
            }
        }
        
        if !cleanedServices.isEmpty {
            let pressureIndicator = aggressiveCleanup ? " (memory pressure)" : ""
            _logger?.debug("DIContainer: Cleaned \(cleanedServices.count) unused services\(pressureIndicator): \(cleanedServices.joined(separator: ", "))", category: .system, context: LogContext())
        }
    }
    
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
    @MainActor
    private func setupRepositories() {
        // Register focused audio services
        register(AudioSessionService.self) { resolver in
            return AudioSessionService()
        }
        
        register(AudioRecordingService.self) { resolver in
            return AudioRecordingService()
        }
        
        register(BackgroundTaskService.self) { resolver in
            return BackgroundTaskService()
        }
        
        register(AudioPermissionService.self) { resolver in
            return AudioPermissionService()
        }
        
        register(RecordingTimerService.self) { resolver in
            return RecordingTimerService()
        }
        
        register(AudioPlaybackService.self) { resolver in
            return AudioPlaybackService()
        }
        
        // Register BackgroundAudioService with orchestrated services
        register(BackgroundAudioService.self) { resolver in
            let sessionService = resolver.resolve(AudioSessionService.self)!
            let recordingService = resolver.resolve(AudioRecordingService.self)!
            let backgroundTaskService = resolver.resolve(BackgroundTaskService.self)!
            let permissionService = resolver.resolve(AudioPermissionService.self)!
            let timerService = resolver.resolve(RecordingTimerService.self)!
            let playbackService = resolver.resolve(AudioPlaybackService.self)!
            
            return BackgroundAudioService(
                sessionService: sessionService,
                recordingService: recordingService,
                backgroundTaskService: backgroundTaskService,
                permissionService: permissionService,
                timerService: timerService,
                playbackService: playbackService
            )
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
    @MainActor
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
        self._eventBus = EventBus.shared
        // Persistence-backed repositories are initialized once ModelContext is injected
        
        // Initialize services from registrations
        self._backgroundAudioService = resolve(BackgroundAudioService.self)!
        self._audioRepository = resolve((any AudioRepository).self)!
        self._startRecordingUseCase = resolve(StartRecordingUseCase.self)!
        self._systemNavigator = resolve((any SystemNavigator).self)!
        self._liveActivityService = resolve((any LiveActivityServiceProtocol).self)!

        // Phase 2: Instantiate optimization services (strong references for app lifetime)
        if self._audioQualityManager == nil {
            self._audioQualityManager = AudioQualityManager()
        }

        // Initialize model management primitives first
        if self._whisperKitModelProvider == nil {
            self._whisperKitModelProvider = WhisperKitModelProvider()
        }
        if self._modelDownloadManager == nil, let provider = self._whisperKitModelProvider {
            self._modelDownloadManager = ModelDownloadManager(provider: provider)
        }
        if self._transcriptionServiceFactory == nil, let dm = self._modelDownloadManager, let provider = self._whisperKitModelProvider {
            self._transcriptionServiceFactory = TranscriptionServiceFactory(downloadManager: dm, modelProvider: provider)
        }

        // Now create the WhisperKit model manager
        if self._whisperKitModelManager == nil, let provider = self._whisperKitModelProvider {
            self._whisperKitModelManager = WhisperKitModelManager(modelProvider: provider)
            // Lifecycle hooks are configured in the manager initializer
        }
        if self._memoryPressureDetector == nil {
            let detector = MemoryPressureDetector()
            detector.startMonitoring()
            self._memoryPressureDetector = detector
        }
        
        // Initialize external API services  
        self._transcriptionAPI = TranscriptionService()
        self._analysisService = analysisService ?? AnalysisService()
        self._moderationService = ModerationService()
        // Coordinator already initialized above
        // Initialize Event Handler Registry with shared EventBus (via protocol)
        self._eventHandlerRegistry = EventHandlerRegistry.shared
        
        // Defer repository initialization until ModelContext is set
        
        _logger?.info("DIContainer: Configured with shared service instances", category: .system, context: LogContext())
        if let memoRepo = self._memoRepository {
            _logger?.debug("DIContainer: MemoRepository: \(ObjectIdentifier(memoRepo))", category: .system, context: LogContext())
        }
        if let repoObj = self._transcriptionRepository {
            _logger?.debug("DIContainer: TranscriptionRepository: \(ObjectIdentifier(repoObj as AnyObject))", category: .system, context: LogContext())
        }
        if let analysisRepoObj = self._analysisRepository {
            _logger?.debug("DIContainer: AnalysisRepository: \(ObjectIdentifier(analysisRepoObj as AnyObject))", category: .system, context: LogContext())
        }
    }
    
    /// Check if container has been properly configured
    @MainActor
    private func ensureConfigured() {
        if !isConfigured {
            configure()
        }
    }
    
    // MARK: - Protocol-Based Service Access
    
    
    
    /// Get transcription API service (legacy - prefer using factory)
    @MainActor
    func transcriptionAPI() -> any TranscriptionAPI {
        ensureConfigured()
        guard let api = _transcriptionAPI else { fatalError("DIContainer not configured: transcriptionAPI") }
        return api
    }
    
    /// Get transcription service factory (modern approach)
    @MainActor
    func transcriptionServiceFactory() -> TranscriptionServiceFactory {
        ensureConfigured()
        guard let factory = _transcriptionServiceFactory else { fatalError("DIContainer not configured: transcriptionServiceFactory") }
        return factory
    }
    
    /// Get model download manager
    @MainActor
    func modelDownloadManager() -> ModelDownloadManager {
        ensureConfigured()
        guard let manager = _modelDownloadManager else { fatalError("DIContainer not configured: modelDownloadManager") }
        return manager
    }

    /// WhisperKit model provider
    @MainActor
    func whisperKitModelProvider() -> WhisperKitModelProvider {
        ensureConfigured()
        guard let provider = _whisperKitModelProvider else { fatalError("DIContainer not configured: whisperKitModelProvider") }
        return provider
    }
    
    /// Create a transcription service based on current user preferences
    @MainActor
    func createTranscriptionService() -> any TranscriptionAPI {
        return transcriptionServiceFactory().createTranscriptionService()
    }
    
    /// Get analysis service
    @MainActor
    func analysisService() -> any AnalysisServiceProtocol {
        ensureConfigured()
        trackServiceAccess("AnalysisService")
        
        // Return local analysis service if enabled, otherwise use API service
        if AppConfiguration.shared.useLocalAnalysis {
            if _localAnalysisService == nil {
                _localAnalysisService = LocalAnalysisService()
                print("🤖 DIContainer: Created LocalAnalysisService instance")
            }
            return _localAnalysisService!
        }
        
        if let existing = _analysisService {
            return existing
        }
        
        // Re-create if deallocated
        _analysisService = AnalysisService()
        return _analysisService!
    }

    /// Optional progressive analysis router (tiny -> base). Falls back to standard service when disabled.
    @MainActor
    func progressiveAnalysisService() -> any AnalysisServiceProtocol {
        ensureConfigured()
        if AppConfiguration.shared.enableProgressiveAnalysisRouting {
            let tiny = localAnalysisService()
            let baseSvc: any AnalysisServiceProtocol
            if let existing = _analysisService { baseSvc = existing } else { _analysisService = AnalysisService(); baseSvc = _analysisService! }
            return ProgressiveAnalysisService(tiny: tiny, base: baseSvc, logger: logger())
        } else {
            return analysisService()
        }
    }

    /// Explicit local analysis service (on-device)
    @MainActor
    func localAnalysisService() -> any AnalysisServiceProtocol {
        ensureConfigured()
        if _localAnalysisService == nil {
            _localAnalysisService = LocalAnalysisService()
        }
        return _localAnalysisService!
    }

    /// Get moderation service
    @MainActor
    func moderationService() -> any ModerationServiceProtocol {
        ensureConfigured()
        guard let svc = _moderationService else { fatalError("DIContainer not configured: moderationService") }
        return svc
    }
    
    /// Get memo repository
    @MainActor
    func memoRepository() -> any MemoRepository {
        ensureConfigured()
        trackServiceAccess("MemoRepository")
        
        if let existing = _memoRepository {
            return existing
        }
        
        // Re-create if needed
        initializePersistenceIfNeeded()
        
        guard let repository = _memoRepository else {
            fatalError("DIContainer: Failed to create MemoRepository")
        }
        
        return repository
    }
    
    /// Get transcription repository
    @MainActor
    func transcriptionRepository() -> any TranscriptionRepository {
        ensureConfigured()
        if _transcriptionRepository == nil { initializePersistenceIfNeeded() }
        guard let repo = _transcriptionRepository else { fatalError("DIContainer not configured: transcriptionRepository") }
        return repo
    }
    
    /// Get analysis repository
    @MainActor
    func analysisRepository() -> any AnalysisRepository {
        ensureConfigured()
        if _analysisRepository == nil { initializePersistenceIfNeeded() }
        guard let repo = _analysisRepository else { fatalError("DIContainer not configured: analysisRepository") }
        return repo
    }
    
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
    
    /// Get start recording use case
    @MainActor
    func startRecordingUseCase() -> StartRecordingUseCase {
        ensureConfigured()
        guard let useCase = _startRecordingUseCase else {
            fatalError("DIContainer not configured: startRecordingUseCase")
        }
        return useCase
    }

    /// Get start transcription use case (cached)
    @MainActor
    func startTranscriptionUseCase() -> any StartTranscriptionUseCaseProtocol {
        ensureConfigured()
        if let uc = _startTranscriptionUseCase { return uc }
        // Lazily build if not already created as part of repository init
        let trRepo = transcriptionRepository()
        let svc = transcriptionServiceFactory().createTranscriptionService()
        let uc = StartTranscriptionUseCase(
            transcriptionRepository: trRepo,
            transcriptionAPI: svc,
            eventBus: eventBus(),
            operationCoordinator: operationCoordinator(),
            moderationService: moderationService()
        )
        _startTranscriptionUseCase = uc
        return uc
    }
    
    /// Get system navigator
    @MainActor
    func systemNavigator() -> any SystemNavigator {
        ensureConfigured()
        guard let nav = _systemNavigator else { fatalError("DIContainer not configured: systemNavigator") }
        return nav
    }
    
    /// Get logger service
    @MainActor
    func logger() -> any LoggerProtocol {
        ensureConfigured()
        guard let logger = _logger else { fatalError("DIContainer not configured: logger") }
        return logger
    }

    // MARK: - Phase 2 Service Accessors

    /// Audio quality manager (voice-optimized and adaptive)
    @MainActor
    func audioQualityManager() -> AudioQualityManager {
        ensureConfigured()
        guard let mgr = _audioQualityManager else { fatalError("DIContainer not configured: audioQualityManager") }
        return mgr
    }

    /// WhisperKit model lifecycle manager (prewarming, idle unload)
    @MainActor
    func whisperKitModelManager() -> WhisperKitModelManager {
        ensureConfigured()
        guard let mgr = _whisperKitModelManager else { fatalError("DIContainer not configured: whisperKitModelManager") }
        return mgr
    }

    /// Memory pressure detector (system-wide monitoring)
    @MainActor
    func memoryPressureDetector() -> MemoryPressureDetector {
        ensureConfigured()
        guard let det = _memoryPressureDetector else { fatalError("DIContainer not configured: memoryPressureDetector") }
        return det
    }

    /// Get transcript exporter service
    @MainActor
    func transcriptExporter() -> any TranscriptExporting {
        ensureConfigured()
        if _transcriptExporter == nil {
            _transcriptExporter = TranscriptExportService()
        }
        return _transcriptExporter!
    }

    /// Get analysis exporter service
    @MainActor
    func analysisExporter() -> any AnalysisExporting {
        ensureConfigured()
        if _analysisExporter == nil {
            _analysisExporter = AnalysisExportService()
        }
        return _analysisExporter!
    }
    
    /// Get operation coordinator service
    @MainActor
    func operationCoordinator() -> any OperationCoordinatorProtocol {
        ensureConfigured()
        return _operationCoordinator
    }
    
    /// Get live activity service
    @MainActor
    func liveActivityService() -> any LiveActivityServiceProtocol {
        ensureConfigured()
        guard let service = _liveActivityService else { fatalError("DIContainer not configured: liveActivityService") }
        return service
    }
    
    /// Get event bus (protocol)
    @MainActor
    func eventBus() -> any EventBusProtocol {
        ensureConfigured()
        guard let bus = _eventBus else { fatalError("DIContainer not configured: eventBus") }
        return bus
    }
    
    /// Get event handler registry (protocol)
    @MainActor
    func eventHandlerRegistry() -> any EventHandlerRegistryProtocol {
        ensureConfigured()
        guard let reg = _eventHandlerRegistry else { fatalError("DIContainer not configured: eventHandlerRegistry") }
        return reg
    }

    /// Spotlight indexing service
    @MainActor
    func spotlightIndexer() -> any SpotlightIndexing {
        ensureConfigured()
        guard let idx = _spotlightIndexer else { fatalError("DIContainer not configured: spotlightIndexer") }
        return idx
    }
    
    // MARK: - EventKit Services
    
    /// Get EventKit repository
    @MainActor
    func eventKitRepository() -> any EventKitRepository {
        ensureConfigured()
        if _eventKitRepository == nil {
            _eventKitRepository = EventKitRepositoryImpl(logger: logger())
        }
        return _eventKitRepository!
    }
    
    /// Get EventKit permission service
    @MainActor
    func eventKitPermissionService() -> any EventKitPermissionServiceProtocol {
        ensureConfigured()
        if _eventKitPermissionService == nil {
            _eventKitPermissionService = EventKitPermissionService(logger: logger())
        }
        return _eventKitPermissionService!
    }
    
    /// Factory: CreateCalendarEventUseCase
    @MainActor
    func createCalendarEventUseCase() -> any CreateCalendarEventUseCaseProtocol {
        ensureConfigured()
        if _createCalendarEventUseCase == nil {
            _createCalendarEventUseCase = CreateCalendarEventUseCase(
                eventKitRepository: eventKitRepository(),
                permissionService: eventKitPermissionService(),
                logger: logger(),
                eventBus: eventBus()
            )
        }
        return _createCalendarEventUseCase!
    }
    
    /// Factory: CreateReminderUseCase
    @MainActor
    func createReminderUseCase() -> any CreateReminderUseCaseProtocol {
        ensureConfigured()
        if _createReminderUseCase == nil {
            _createReminderUseCase = CreateReminderUseCase(
                eventKitRepository: eventKitRepository(),
                permissionService: eventKitPermissionService(),
                logger: logger(),
                eventBus: eventBus()
            )
        }
        return _createReminderUseCase!
    }
    
    /// Factory: DetectEventsAndRemindersUseCase
    @MainActor
    func detectEventsAndRemindersUseCase() -> any DetectEventsAndRemindersUseCaseProtocol {
        ensureConfigured()
        if _detectEventsAndRemindersUseCase == nil {
            _detectEventsAndRemindersUseCase = DetectEventsAndRemindersUseCase(
                analysisService: analysisService(),
                localAnalysisService: localAnalysisService(),
                analysisRepository: analysisRepository(),
                logger: logger(),
                eventBus: eventBus(),
                operationCoordinator: operationCoordinator(),
                useLocalAnalysis: false // Default to cloud analysis
            )
        }
        return _detectEventsAndRemindersUseCase!
    }
    
    /// Factory: CreateTranscriptShareFileUseCase
    @MainActor
    func createTranscriptShareFileUseCase() -> CreateTranscriptShareFileUseCase {
        ensureConfigured()
        return CreateTranscriptShareFileUseCase(
            exporter: transcriptExporter(),
            logger: logger()
        )
    }

    /// Factory: CreateAnalysisShareFileUseCase
    @MainActor
    func createAnalysisShareFileUseCase() -> CreateAnalysisShareFileUseCase {
        ensureConfigured()
        return CreateAnalysisShareFileUseCase(
            analysisRepository: analysisRepository(),
            exporter: analysisExporter(),
            logger: logger()
        )
    }

    // MARK: - SwiftData ModelContext
    @MainActor
    func setModelContext(_ context: ModelContext) {
        self._modelContext = context
        _logger?.debug("DIContainer: ModelContext injected", category: .system, context: LogContext())
        initializePersistenceIfNeeded()
    }

    @MainActor
    func modelContext() -> ModelContext {
        ensureConfigured()
        guard let context = _modelContext else { fatalError("DIContainer not configured: modelContext") }
        return context
    }

    // MARK: - Persistence Initialization
    @MainActor
    private func initializePersistenceIfNeeded() {
        guard _memoRepository == nil || _transcriptionRepository == nil || _analysisRepository == nil else { return }
        guard let ctx = _modelContext else {
            _logger?.warning("ModelContext not yet available; deferring repository setup", category: .system, context: LogContext(), error: nil)
            return
        }

        // Initialize SwiftData-backed repositories
        let trRepo = TranscriptionRepositoryImpl(context: ctx)
        self._transcriptionRepository = trRepo
        let anRepo = AnalysisRepositoryImpl(context: ctx)
        self._analysisRepository = anRepo

        guard let trFactory = _transcriptionServiceFactory, let bus = _eventBus, let mod = _moderationService else {
            fatalError("DIContainer not fully configured: missing dependencies for memo repository")
        }
        let transcriptionService = trFactory.createTranscriptionService()
        let startTranscriptionUseCase = StartTranscriptionUseCase(
            transcriptionRepository: trRepo,
            transcriptionAPI: transcriptionService,
            eventBus: bus,
            operationCoordinator: _operationCoordinator,
            moderationService: mod
        )
        // Cache for reuse by other orchestrators (e.g., MemoEventHandler)
        self._startTranscriptionUseCase = startTranscriptionUseCase
        let getTranscriptionStateUseCase = GetTranscriptionStateUseCase(transcriptionRepository: trRepo)
        let retryTranscriptionUseCase = RetryTranscriptionUseCase(transcriptionRepository: trRepo, transcriptionAPI: transcriptionService)
        self._memoRepository = MemoRepositoryImpl(
            context: ctx,
            transcriptionRepository: trRepo,
            startTranscriptionUseCase: startTranscriptionUseCase,
            getTranscriptionStateUseCase: getTranscriptionStateUseCase,
            retryTranscriptionUseCase: retryTranscriptionUseCase
        )

        // Spotlight Indexer (optional feature) — requires memoRepository to be initialized
        if let memoRepo = self._memoRepository {
            self._spotlightIndexer = SpotlightIndexer(
                logger: self._logger ?? Logger.shared,
                memoRepository: memoRepo,
                transcriptionRepository: trRepo,
                analysisRepository: anRepo
            )
        }
    }
    
}

// The container is accessed from SwiftUI on the main actor
// and not intended to be sent across threads. Mark as unchecked
// to satisfy strict concurrency for the singleton.
extension DIContainer: @unchecked Sendable {}

// MARK: - SwiftUI Environment Support

import SwiftUI

/// Environment key for DIContainer
private struct DIContainerKey: EnvironmentKey {
    static var defaultValue: DIContainer { DIContainer.shared }
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
