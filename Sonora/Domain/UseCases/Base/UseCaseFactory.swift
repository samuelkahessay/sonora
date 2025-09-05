import Foundation

/// Factory for creating Use Cases with proper dependency injection
/// Centralizes Use Case creation and eliminates boilerplate
/// NOTE: This is a foundation for future refactoring - currently partially implemented
@MainActor
protocol UseCaseFactory: Sendable {
    
    // MARK: - Recording Use Cases
    func createStartRecordingUseCase() -> StartRecordingUseCase
    func createStopRecordingUseCase() -> StopRecordingUseCase
    func createRequestMicrophonePermissionUseCase() -> RequestMicrophonePermissionUseCase
    func createHandleNewRecordingUseCase() -> HandleNewRecordingUseCase
    
    // MARK: - Memo Management Use Cases
    func createLoadMemosUseCase() -> LoadMemosUseCase
    func createDeleteMemoUseCase() -> DeleteMemoUseCase
    func createPlayMemoUseCase() -> PlayMemoUseCase
    func createRenameMemoUseCase() -> RenameMemoUseCase
    
    // MARK: - Transcription Use Cases
    func createStartTranscriptionUseCase() -> StartTranscriptionUseCase
    func createRetryTranscriptionUseCase() -> RetryTranscriptionUseCase
    func createGetTranscriptionStateUseCase() -> GetTranscriptionStateUseCase
    
    // MARK: - Analysis Use Cases
    func createAnalyzeContentUseCase() -> AnalyzeContentUseCase
    func createAnalyzeDistillUseCase() -> AnalyzeDistillUseCase
    func createAnalyzeDistillParallelUseCase() -> AnalyzeDistillParallelUseCase
    func createAnalyzeThemesUseCase() -> AnalyzeThemesUseCase
    func createAnalyzeTodosUseCase() -> AnalyzeTodosUseCase
    
    // MARK: - Export Use Cases
    func createTranscriptShareFileUseCase() -> CreateTranscriptShareFileUseCase
    func createAnalysisShareFileUseCase() -> CreateAnalysisShareFileUseCase
}

/// Default implementation of UseCaseFactory using DIContainer
/// Provides centralized, consistent Use Case creation with proper dependency injection
@MainActor
final class DefaultUseCaseFactory: UseCaseFactory {
    
    private let container: DIContainer
    
    init(container: DIContainer = DIContainer.shared) {
        self.container = container
    }
    
    // MARK: - Recording Use Cases
    
    func createStartRecordingUseCase() -> StartRecordingUseCase {
        return StartRecordingUseCase(
            audioRepository: container.audioRepository(),
            operationCoordinator: container.operationCoordinator()
        )
    }
    
    func createStopRecordingUseCase() -> StopRecordingUseCase {
        return StopRecordingUseCase(
            audioRepository: container.audioRepository(),
            operationCoordinator: container.operationCoordinator()
        )
    }
    
    func createRequestMicrophonePermissionUseCase() -> RequestMicrophonePermissionUseCase {
        return RequestMicrophonePermissionUseCase(
            logger: container.logger()
        )
    }
    
    func createHandleNewRecordingUseCase() -> HandleNewRecordingUseCase {
        return HandleNewRecordingUseCase(
            memoRepository: container.memoRepository(),
            eventBus: container.eventBus()
        )
    }
    
    // MARK: - Memo Management Use Cases
    
    func createLoadMemosUseCase() -> LoadMemosUseCase {
        return LoadMemosUseCase(
            memoRepository: container.memoRepository()
        )
    }
    
    func createDeleteMemoUseCase() -> DeleteMemoUseCase {
        return DeleteMemoUseCase(
            memoRepository: container.memoRepository(),
            analysisRepository: container.analysisRepository(),
            transcriptionRepository: container.transcriptionRepository(),
            logger: container.logger()
        )
    }
    
    func createPlayMemoUseCase() -> PlayMemoUseCase {
        return PlayMemoUseCase(
            memoRepository: container.memoRepository()
        )
    }
    
    func createRenameMemoUseCase() -> RenameMemoUseCase {
        return RenameMemoUseCase(
            memoRepository: container.memoRepository()
        )
    }
    
    // MARK: - Transcription Use Cases
    
    func createStartTranscriptionUseCase() -> StartTranscriptionUseCase {
        // TODO: Implement proper factory method - complex constructor requires investigation
        fatalError("StartTranscriptionUseCase factory method not yet implemented")
    }
    
    func createRetryTranscriptionUseCase() -> RetryTranscriptionUseCase {
        return RetryTranscriptionUseCase(
            transcriptionRepository: container.transcriptionRepository(),
            transcriptionAPI: container.createTranscriptionService()
        )
    }
    
    func createGetTranscriptionStateUseCase() -> GetTranscriptionStateUseCase {
        return GetTranscriptionStateUseCase(
            transcriptionRepository: container.transcriptionRepository()
        )
    }
    
    // MARK: - Analysis Use Cases
    
    func createAnalyzeContentUseCase() -> AnalyzeContentUseCase {
        return AnalyzeContentUseCase(
            analysisService: container.analysisService(),
            analysisRepository: container.analysisRepository(),
            logger: container.logger(),
            eventBus: container.eventBus()
        )
    }
    
    func createAnalyzeDistillUseCase() -> AnalyzeDistillUseCase {
        return AnalyzeDistillUseCase(
            analysisService: container.analysisService(),
            analysisRepository: container.analysisRepository(),
            logger: container.logger(),
            eventBus: container.eventBus(),
            operationCoordinator: container.operationCoordinator()
        )
    }
    
    func createAnalyzeDistillParallelUseCase() -> AnalyzeDistillParallelUseCase {
        return AnalyzeDistillParallelUseCase(
            analysisService: container.analysisService(),
            analysisRepository: container.analysisRepository(),
            logger: container.logger(),
            eventBus: container.eventBus(),
            operationCoordinator: container.operationCoordinator()
        )
    }
    
    func createAnalyzeThemesUseCase() -> AnalyzeThemesUseCase {
        return AnalyzeThemesUseCase(
            analysisService: container.analysisService(),
            analysisRepository: container.analysisRepository(),
            logger: container.logger(),
            eventBus: container.eventBus()
        )
    }
    
    func createAnalyzeTodosUseCase() -> AnalyzeTodosUseCase {
        return AnalyzeTodosUseCase(
            analysisService: container.analysisService(),
            analysisRepository: container.analysisRepository(),
            logger: container.logger(),
            eventBus: container.eventBus()
        )
    }
    
    // MARK: - Export Use Cases
    
    func createTranscriptShareFileUseCase() -> CreateTranscriptShareFileUseCase {
        return container.createTranscriptShareFileUseCase()
    }
    
    func createAnalysisShareFileUseCase() -> CreateAnalysisShareFileUseCase {
        return container.createAnalysisShareFileUseCase()
    }
}

// MARK: - DIContainer Extension

extension DIContainer {
    
    /// Get the UseCaseFactory instance
    @MainActor
    func useCaseFactory() -> UseCaseFactory {
        return DefaultUseCaseFactory(container: self)
    }
}