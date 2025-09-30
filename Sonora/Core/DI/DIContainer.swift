import Combine
import Foundation
import SwiftData
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
    var _transcriptionServiceFactory: TranscriptionServiceFactory?
    var _analysisService: AnalysisService?
    var _memoRepository: MemoRepositoryImpl?
    var _transcriptionRepository: (any TranscriptionRepository)?
    var _analysisRepository: (any AnalysisRepository)?
    var _recordingUsageRepository: (any RecordingUsageRepository)?
    var _recordingQuotaPolicy: (any RecordingQuotaPolicyProtocol)?
    // Prompts
    private var _promptUsageRepository: (any PromptUsageRepository)?
    private var _promptCatalog: (any PromptCatalog)?
    private var _dateProvider: (any DateProvider)?
    private var _localizationProvider: (any LocalizationProvider)?
    var _logger: (any LoggerProtocol)?
    var _audioRepository: (any AudioRepository)?
    private var _transcriptExporter: (any TranscriptExporting)?
    private var _analysisExporter: (any AnalysisExporting)?
    private var _dataExporter: (any DataExporting)?
    private var _startTranscriptionUseCase: (any StartTranscriptionUseCaseProtocol)?
    private var _systemNavigator: (any SystemNavigator)?
    private var _liveActivityService: (any LiveActivityServiceProtocol)?
    private var _eventBus: (any EventBusProtocol)?
    private var _eventHandlerRegistry: (any EventHandlerRegistryProtocol)?
    var _getRemainingMonthlyQuotaUseCase: (any GetRemainingMonthlyQuotaUseCaseProtocol)?
    var _storeKitService: (any StoreKitServiceProtocol)?
    var _moderationService: (any ModerationServiceProtocol)?
    private var _spotlightIndexer: (any SpotlightIndexing)?
    var _modelContext: ModelContext? // Keep strong reference to ModelContext
    var _fillerWordFilter: (any FillerWordFiltering)?
    // Titles
    private var _titleService: (any TitleServiceProtocol)?
    private var _autoTitleJobRepository: (any AutoTitleJobRepository)?
    private var _titleGenerationCoordinator: TitleGenerationCoordinator?
    private var _generateAutoTitleUseCase: (any GenerateAutoTitleUseCaseProtocol)?

    // MARK: - Phase 2: Core Optimization Services
    private var _audioQualityManager: AudioQualityManager?
    private var _memoryPressureDetector: MemoryPressureDetector?

    // MARK: - EventKit Services (Protocol References)
    private var _eventKitRepository: (any EventKitRepository)?
    private var _eventKitPermissionService: (any EventKitPermissionServiceProtocol)?
    private var _createCalendarEventUseCase: (any CreateCalendarEventUseCaseProtocol)?
    private var _createReminderUseCase: (any CreateReminderUseCaseProtocol)?
    private var _detectEventsAndRemindersUseCase: (any DetectEventsAndRemindersUseCaseProtocol)?
    private var _buildExportBundleUseCase: (any BuildExportBundleUseCaseProtocol)?

    // MARK: - Core Services (Strong References)
    // These services need to stay alive for the app lifetime
    private var _operationCoordinator: (any OperationCoordinatorProtocol)!

    // MARK: - Service Lifecycle Management
    private var serviceAccessTimes: [String: Date] = [:]
    private let serviceCleanupInterval: TimeInterval = 300 // 5 minutes
    private var lastCleanupTime = Date()

    // MARK: - Helpers
    private func requireResolve<T>(_ type: T.Type, _ name: String) -> T {
        guard let value = resolve(type) else { fatalError("DIContainer resolve failed: \(name)") }
        return value
    }

    // MARK: - Initialization
    private init() {
        // Services will be injected after initialization
        print("🏭 DIContainer: Initialized, waiting for service injection")
    }

    // MARK: - Configuration Guard
    private var isConfigured: Bool = false

    // MARK: - Memory Management

    /// Track service access for lifecycle management
    func trackServiceAccess(_ serviceName: String) {
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
        register(AudioSessionService.self) { _ in
            AudioSessionService()
        }

        register(AudioRecordingService.self) { _ in
            AudioRecordingService()
        }

        register(BackgroundTaskService.self) { _ in
            BackgroundTaskService()
        }

        register(AudioPermissionService.self) { _ in
            AudioPermissionService()
        }

        register(RecordingTimerService.self) { _ in
            RecordingTimerService()
        }

        // Register BackgroundAudioService with orchestrated services
        register(BackgroundAudioService.self) { resolver in
            let sessionService = (resolver as? Self)?.requireResolve(AudioSessionService.self, "AudioSessionService")
                ?? { fatalError("DIContainer: resolver not DIContainer") }()
            let recordingService = (resolver as? Self)?.requireResolve(AudioRecordingService.self, "AudioRecordingService")
                ?? { fatalError("DIContainer: resolver not DIContainer") }()
            let backgroundTaskService = (resolver as? Self)?.requireResolve(BackgroundTaskService.self, "BackgroundTaskService")
                ?? { fatalError("DIContainer: resolver not DIContainer") }()
            let permissionService = (resolver as? Self)?.requireResolve(AudioPermissionService.self, "AudioPermissionService")
                ?? { fatalError("DIContainer: resolver not DIContainer") }()
            let timerService = (resolver as? Self)?.requireResolve(RecordingTimerService.self, "RecordingTimerService")
                ?? { fatalError("DIContainer: resolver not DIContainer") }()
            return BackgroundAudioService(
                sessionService: sessionService,
                recordingService: recordingService,
                backgroundTaskService: backgroundTaskService,
                permissionService: permissionService,
                timerService: timerService
            )
        }

        // Register SystemNavigator
        register((any SystemNavigator).self) { _ in
            SystemNavigatorImpl() as any SystemNavigator
        }

        // Register AudioRepository 
        register((any AudioRepository).self) { resolver in
            let backgroundService = (resolver as? Self)?.requireResolve(BackgroundAudioService.self, "BackgroundAudioService")
                ?? { fatalError("DIContainer: resolver not DIContainer") }()
            return AudioRepositoryImpl(backgroundAudioService: backgroundService) as any AudioRepository
        }

        // Register RecordingUsageRepository (UserDefaults-backed)
        register((any RecordingUsageRepository).self) { _ in
            RecordingUsageRepositoryImpl() as any RecordingUsageRepository
        }

        // Register StoreKit service for subscriptions
        register((any StoreKitServiceProtocol).self) { _ in
            StoreKitService() as any StoreKitServiceProtocol
        }

        // Register RecordingQuotaPolicy (protocol-first)
        register((any RecordingQuotaPolicyProtocol).self) { resolver in
            let sk = resolver.resolve((any StoreKitServiceProtocol).self) ?? (StoreKitService() as any StoreKitServiceProtocol)
            return DefaultRecordingQuotaPolicy { sk.isPro } as any RecordingQuotaPolicyProtocol
        }

        // Register LiveActivityService
        register((any LiveActivityServiceProtocol).self) { _ in
            LiveActivityService() as any LiveActivityServiceProtocol
        }

        // Register Prompt Catalog & Providers
        register((any PromptCatalog).self) { _ in
            // Use file-backed catalog only.
            let fileCatalog = PromptCatalogFile() as any PromptCatalog
            return fileCatalog
        }
        register((any DateProvider).self) { _ in
            DefaultDateProvider() as any DateProvider
        }
        register((any LocalizationProvider).self) { _ in
            DefaultLocalizationProvider() as any LocalizationProvider
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
        // initialize DI-managed services
        if let repo = resolve((any AudioRepository).self) as (any AudioRepository)? {
            self._audioRepository = repo
        } else { fatalError("DIContainer not configured: AudioRepository") }
        if let nav = resolve((any SystemNavigator).self) as (any SystemNavigator)? {
            self._systemNavigator = nav
        } else { fatalError("DIContainer not configured: SystemNavigator") }
        if let las = resolve((any LiveActivityServiceProtocol).self) as (any LiveActivityServiceProtocol)? {
            self._liveActivityService = las
        } else { fatalError("DIContainer not configured: LiveActivityService") }

        // Phase 2: Instantiate optimization services (strong references for app lifetime)
        if self._audioQualityManager == nil {
            self._audioQualityManager = AudioQualityManager()
        }

        if self._transcriptionServiceFactory == nil {
            self._transcriptionServiceFactory = TranscriptionServiceFactory()
        }
        if self._memoryPressureDetector == nil {
            let detector = MemoryPressureDetector()
            detector.startMonitoring()
            self._memoryPressureDetector = detector
        }

        // Initialize external API services  
        // prefer factory-based creation; remove legacy _transcriptionAPI instance
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
    func ensureConfigured() {
        if !isConfigured {
            configure()
        }
    }

    // MARK: - Protocol-Based Service Access

    /// Get transcription service factory (modern approach)
    @MainActor
    func transcriptionServiceFactory() -> TranscriptionServiceFactory {
        ensureConfigured()
        guard let factory = _transcriptionServiceFactory else { fatalError("DIContainer not configured: transcriptionServiceFactory") }
        return factory
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
            moderationService: moderationService(),
            fillerWordFilter: fillerWordFilter()
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
        guard let exporter = _transcriptExporter else { fatalError("Failed to init transcriptExporter") }
        return exporter
    }

    /// Get analysis exporter service
    @MainActor
    func analysisExporter() -> any AnalysisExporting {
        ensureConfigured()
        if _analysisExporter == nil {
            _analysisExporter = AnalysisExportService()
        }
        guard let exporter = _analysisExporter else { fatalError("Failed to init analysisExporter") }
        return exporter
    }

    // MARK: - Title Service & Use Case
    @MainActor
    func titleService() -> any TitleServiceProtocol {
        ensureConfigured()
        if _titleService == nil { _titleService = TitleService() }
        guard let svc = _titleService else { fatalError("Failed to init titleService") }
        return svc
    }

    @MainActor
    func autoTitleJobRepository() -> any AutoTitleJobRepository {
        ensureConfigured()
        if let repo = _autoTitleJobRepository { return repo }
        guard let ctx = _modelContext else { fatalError("ModelContext not configured: autoTitleJobRepository") }
        let repo = AutoTitleJobRepositoryImpl(context: ctx)
        _autoTitleJobRepository = repo
        return repo
    }

    @MainActor
    func titleGenerationCoordinator() -> TitleGenerationCoordinator {
        ensureConfigured()
        if let coordinator = _titleGenerationCoordinator { return coordinator }
        let coordinator = TitleGenerationCoordinator(
            titleService: titleService(),
            memoRepository: memoRepository(),
            transcriptionRepository: transcriptionRepository(),
            jobRepository: autoTitleJobRepository(),
            logger: logger()
        )
        _titleGenerationCoordinator = coordinator
        return coordinator
    }

    @MainActor
    func generateAutoTitleUseCase() -> any GenerateAutoTitleUseCaseProtocol {
        ensureConfigured()
        if let uc = _generateAutoTitleUseCase { return uc }
        let uc = GenerateAutoTitleUseCase(
            memoRepository: memoRepository(),
            coordinator: titleGenerationCoordinator(),
            logger: logger()
        )
        _generateAutoTitleUseCase = uc
        return uc
    }

    @MainActor
    func dataExporter() -> any DataExporting {
        ensureConfigured()
        if _dataExporter == nil {
            _dataExporter = ZipDataExportService()
        }
        guard let de = _dataExporter else { fatalError("Failed to init dataExporter") }
        return de
    }

    @MainActor
    func buildExportBundleUseCase() -> any BuildExportBundleUseCaseProtocol {
        ensureConfigured()
        if _buildExportBundleUseCase == nil {
            let exporter = dataExporter()
            let logger = logger()
            _buildExportBundleUseCase = BuildExportBundleUseCase(exporter: exporter, logger: logger)
        }
        guard let useCase = _buildExportBundleUseCase else { fatalError("Failed to init buildExportBundleUseCase") }
        return useCase
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
        guard let repo = _eventKitRepository else { fatalError("Failed to init eventKitRepository") }
        return repo
    }

    /// Get EventKit permission service
    @MainActor
    func eventKitPermissionService() -> any EventKitPermissionServiceProtocol {
        ensureConfigured()
        if _eventKitPermissionService == nil {
            _eventKitPermissionService = EventKitPermissionService(logger: logger())
        }
        guard let svc = _eventKitPermissionService else { fatalError("Failed to init eventKitPermissionService") }
        return svc
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
        guard let uc = _createCalendarEventUseCase else { fatalError("Failed to init createCalendarEventUseCase") }
        return uc
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
        guard let uc = _createReminderUseCase else { fatalError("Failed to init createReminderUseCase") }
        return uc
    }

    /// Factory: DetectEventsAndRemindersUseCase
    @MainActor
    func detectEventsAndRemindersUseCase() -> any DetectEventsAndRemindersUseCaseProtocol {
        ensureConfigured()
        if _detectEventsAndRemindersUseCase == nil {
            _detectEventsAndRemindersUseCase = DetectEventsAndRemindersUseCase(
                analysisService: analysisService(),
                analysisRepository: analysisRepository(),
                logger: logger(),
                eventBus: eventBus(),
                operationCoordinator: operationCoordinator()
            )
        }
        guard let uc = _detectEventsAndRemindersUseCase else { fatalError("Failed to init detectEventsAndRemindersUseCase") }
        return uc
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

    // MARK: - Prompts: Providers & Catalog
    @MainActor
    func dateProvider() -> any DateProvider {
        ensureConfigured()
        if _dateProvider == nil { _dateProvider = resolve((any DateProvider).self) }
        guard let dp = _dateProvider else { fatalError("Failed to resolve dateProvider") }
        return dp
    }

    @MainActor
    func localizationProvider() -> any LocalizationProvider {
        ensureConfigured()
        if _localizationProvider == nil { _localizationProvider = resolve((any LocalizationProvider).self) }
        guard let lp = _localizationProvider else { fatalError("Failed to resolve localizationProvider") }
        return lp
    }

    @MainActor
    func promptCatalog() -> any PromptCatalog {
        ensureConfigured()
        if _promptCatalog == nil { _promptCatalog = resolve((any PromptCatalog).self) }
        guard let pc = _promptCatalog else { fatalError("Failed to resolve promptCatalog") }
        return pc
    }

    @MainActor
    func promptUsageRepository() -> any PromptUsageRepository {
        ensureConfigured()
        if let repo = _promptUsageRepository { return repo }
        guard let ctx = _modelContext else { fatalError("DIContainer not configured: modelContext") }
        let repo = PromptUsageRepositoryImpl(context: ctx)
        _promptUsageRepository = repo
        return repo
    }

    // MARK: - Prompts: Use Cases
    @MainActor
    func getDynamicPromptUseCase() -> any GetDynamicPromptUseCaseProtocol {
        ensureConfigured()
        return GetDynamicPromptUseCase(
            catalog: promptCatalog(),
            usageRepository: promptUsageRepository(),
            dateProvider: dateProvider(),
            localization: localizationProvider(),
            logger: logger(),
            eventBus: eventBus()
        )
    }

    @MainActor
    func getPromptCategoryUseCase() -> any GetPromptCategoryUseCaseProtocol {
        ensureConfigured()
        return GetPromptCategoryUseCase(
            catalog: promptCatalog(),
            usageRepository: promptUsageRepository(),
            dateProvider: dateProvider(),
            localization: localizationProvider(),
            logger: logger(),
            eventBus: eventBus()
        )
    }

    // MARK: - Persistence Initialization
    @MainActor
    func initializePersistenceIfNeeded() {
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
        let titleJobRepo = AutoTitleJobRepositoryImpl(context: ctx)
        self._autoTitleJobRepository = titleJobRepo

        guard let trFactory = _transcriptionServiceFactory, let bus = _eventBus, let mod = _moderationService else {
            fatalError("DIContainer not fully configured: missing dependencies for memo repository")
        }
        let transcriptionService = trFactory.createTranscriptionService()
        let startTranscriptionUseCase = StartTranscriptionUseCase(
            transcriptionRepository: trRepo,
            transcriptionAPI: transcriptionService,
            eventBus: bus,
            operationCoordinator: _operationCoordinator,
            moderationService: mod,
            fillerWordFilter: fillerWordFilter()
        )
        // Cache for reuse by other orchestrators (e.g., MemoEventHandler)
        self._startTranscriptionUseCase = startTranscriptionUseCase
        self._memoRepository = MemoRepositoryImpl(
            context: ctx,
            transcriptionRepository: trRepo,
            autoTitleJobRepository: titleJobRepo
        )

        // Initialize PromptUsageRepository (SwiftData)
        self._promptUsageRepository = PromptUsageRepositoryImpl(context: ctx)

        // Spotlight Indexer (optional feature) — requires memoRepository to be initialized
        if let memoRepo = self._memoRepository {
            self._spotlightIndexer = SpotlightIndexer(
                logger: self._logger ?? Logger.shared,
                memoRepository: memoRepo,
                transcriptionRepository: trRepo
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
