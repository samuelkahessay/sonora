import Foundation
import Combine

/// Protocol for creating ViewModels with proper dependency injection
/// Eliminates direct DIContainer access from ViewModels
@MainActor
protocol ViewModelFactory {
    func createRecordingViewModel() -> RecordingViewModel
    func createMemoListViewModel() -> MemoListViewModel  
    func createMemoDetailViewModel() -> MemoDetailViewModel
    func createAnalysisViewModel() -> AnalysisViewModel
    func createOnboardingViewModel() -> OnboardingViewModel
    func createOperationStatusViewModel() -> OperationStatusViewModel
}

/// Default implementation of ViewModelFactory using DIContainer
/// Centralizes all ViewModel creation and dependency injection
@MainActor  
final class DefaultViewModelFactory: ViewModelFactory {
    
    private let container: DIContainer
    
    init(container: DIContainer = DIContainer.shared) {
        self.container = container
    }
    
    // MARK: - ViewModels Creation
    
    func createRecordingViewModel() -> RecordingViewModel {
        let audioRepository = container.audioRepository()
        let memoRepository = container.memoRepository()
        let logger = container.logger()
        
        return RecordingViewModel(
            startRecordingUseCase: StartRecordingUseCase(
                audioRepository: audioRepository,
                operationCoordinator: container.operationCoordinator()
            ),
            stopRecordingUseCase: StopRecordingUseCase(
                audioRepository: audioRepository,
                operationCoordinator: container.operationCoordinator()
            ),
            requestPermissionUseCase: RequestMicrophonePermissionUseCase(logger: logger),
            handleNewRecordingUseCase: HandleNewRecordingUseCase(memoRepository: memoRepository, eventBus: container.eventBus()),
            audioRepository: audioRepository,
            operationCoordinator: container.operationCoordinator(),
            systemNavigator: container.systemNavigator(),
            canStartRecordingUseCase: container.canStartRecordingUseCase(),
            consumeRecordingUsageUseCase: container.consumeRecordingUsageUseCase(),
            resetDailyUsageIfNeededUseCase: container.resetDailyUsageIfNeededUseCase(),
            getRemainingDailyQuotaUseCase: container.getRemainingDailyQuotaUseCase(),
            modelDownloadManager: container.modelDownloadManager()
        )
    }
    
    func createMemoListViewModel() -> MemoListViewModel {
        let memoRepository = container.memoRepository()
        let transcriptionRepository = container.transcriptionRepository()
        let transcriptionAPI = container.createTranscriptionService()
        
        let startTranscriptionUseCase = StartTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: transcriptionAPI,
            eventBus: container.eventBus(),
            operationCoordinator: container.operationCoordinator(),
            moderationService: container.moderationService()
        )
        let retryTranscriptionUseCase = RetryTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: transcriptionAPI
        )
        let getTranscriptionStateUseCase = GetTranscriptionStateUseCase(
            transcriptionRepository: transcriptionRepository
        )
        let renameMemoUseCase = RenameMemoUseCase(
            memoRepository: memoRepository
        )
        
        return MemoListViewModel(
            loadMemosUseCase: LoadMemosUseCase(memoRepository: memoRepository),
            deleteMemoUseCase: DeleteMemoUseCase(
                memoRepository: memoRepository,
                analysisRepository: container.analysisRepository(),
                transcriptionRepository: transcriptionRepository,
                logger: container.logger()
            ),
            playMemoUseCase: PlayMemoUseCase(memoRepository: memoRepository),
            startTranscriptionUseCase: startTranscriptionUseCase,
            retryTranscriptionUseCase: retryTranscriptionUseCase,
            getTranscriptionStateUseCase: getTranscriptionStateUseCase,
            renameMemoUseCase: renameMemoUseCase,
            memoRepository: memoRepository,
            transcriptionRepository: transcriptionRepository
        )
    }
    
    func createMemoDetailViewModel() -> MemoDetailViewModel {
        let transcriptionRepository = container.transcriptionRepository()
        let transcriptionAPI = container.createTranscriptionService()
        let analysisRepository = container.analysisRepository()
        let memoRepository = container.memoRepository()
        let logger = container.logger()
        let eventBus = container.eventBus()
        let moderationService = container.moderationService()
        let operationCoordinator = container.operationCoordinator()
        
        let startTranscriptionUseCase = StartTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: transcriptionAPI,
            eventBus: eventBus,
            operationCoordinator: operationCoordinator,
            moderationService: moderationService
        )
        let retryTranscriptionUseCase = RetryTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: transcriptionAPI
        )
        let getTranscriptionStateUseCase = GetTranscriptionStateUseCase(
            transcriptionRepository: transcriptionRepository
        )
        
        return MemoDetailViewModel(
            playMemoUseCase: PlayMemoUseCase(memoRepository: memoRepository),
            startTranscriptionUseCase: startTranscriptionUseCase,
            retryTranscriptionUseCase: retryTranscriptionUseCase,
            getTranscriptionStateUseCase: getTranscriptionStateUseCase,
            analyzeDistillUseCase: AnalyzeDistillUseCase(analysisService: container.analysisService(), analysisRepository: analysisRepository, logger: logger, eventBus: eventBus, operationCoordinator: operationCoordinator),
            analyzeDistillParallelUseCase: AnalyzeDistillParallelUseCase(analysisService: container.analysisService(), analysisRepository: analysisRepository, logger: logger, eventBus: eventBus, operationCoordinator: operationCoordinator),
            analyzeContentUseCase: AnalyzeContentUseCase(analysisService: container.analysisService(), analysisRepository: analysisRepository, logger: logger, eventBus: eventBus),
            analyzeThemesUseCase: AnalyzeThemesUseCase(analysisService: container.analysisService(), analysisRepository: analysisRepository, logger: logger, eventBus: eventBus),
            analyzeTodosUseCase: AnalyzeTodosUseCase(analysisService: container.analysisService(), analysisRepository: analysisRepository, logger: logger, eventBus: eventBus),
            renameMemoUseCase: RenameMemoUseCase(memoRepository: memoRepository),
            createTranscriptShareFileUseCase: container.createTranscriptShareFileUseCase(),
            createAnalysisShareFileUseCase: container.createAnalysisShareFileUseCase(),
            memoRepository: memoRepository,
            operationCoordinator: operationCoordinator
        )
    }
    
    func createAnalysisViewModel() -> AnalysisViewModel {
        return AnalysisViewModel()
    }
    
    func createOnboardingViewModel() -> OnboardingViewModel {
        return OnboardingViewModel(
            requestMicrophonePermissionUseCase: RequestMicrophonePermissionUseCase(logger: container.logger()),
            onboardingConfiguration: OnboardingConfiguration.shared
        )
    }
    
    func createOperationStatusViewModel() -> OperationStatusViewModel {
        return OperationStatusViewModel(
            operationCoordinator: container.operationCoordinator(),
            logger: container.logger()
        )
    }
}

// MARK: - ViewModelFactory Extension for DIContainer

extension DIContainer {
    
    /// Get the ViewModelFactory instance
    @MainActor
    func viewModelFactory() -> ViewModelFactory {
        return DefaultViewModelFactory(container: self)
    }
}
