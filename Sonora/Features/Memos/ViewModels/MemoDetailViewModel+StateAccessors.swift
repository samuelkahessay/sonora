import Foundation

// MARK: - Backward Compatibility Properties (moved)

extension MemoDetailViewModel {

    // MARK: - Transcription Properties
    var transcriptionState: TranscriptionState {
        get { state.transcription.state }
        set { state.transcription.state = newValue }
    }

    var transcriptionProgressPercent: Double? {
        get { state.transcription.progressPercent }
        set { state.transcription.progressPercent = newValue }
    }

    var transcriptionProgressStep: String? {
        get { state.transcription.progressStep }
        set { state.transcription.progressStep = newValue }
    }

    var transcriptionModerationFlagged: Bool {
        get { state.transcription.moderationFlagged }
        set { state.transcription.moderationFlagged = newValue }
    }

    var transcriptionModerationCategories: [String: Bool] {
        get { state.transcription.moderationCategories }
        set { state.transcription.moderationCategories = newValue }
    }

    var transcriptionServiceBadge: String? {
        state.transcription.serviceDisplayName
    }

    var transcriptionServiceIcon: String? {
        state.transcription.serviceIconName
    }

    // MARK: - Audio Properties
    var isPlaying: Bool {
        get { state.audio.isPlaying }
        set { state.audio.isPlaying = newValue }
    }

    // MARK: - Analysis Properties
    var selectedAnalysisMode: AnalysisMode? {
        get { state.analysis.selectedMode }
        set { state.analysis.selectedMode = newValue }
    }

    var analysisPayload: AnalysisResultPayload? {
        get { state.analysis.payload }
        set { state.analysis.payload = newValue }
    }

    var isAnalyzing: Bool {
        get { state.analysis.isAnalyzing }
        set { state.analysis.isAnalyzing = newValue }
    }

    var analysisError: String? {
        get { state.analysis.error }
        set { state.analysis.error = newValue }
    }

    var analysisCacheStatus: String? {
        get { state.analysis.cacheStatus }
        set { state.analysis.cacheStatus = newValue }
    }

    var analysisPerformanceInfo: String? {
        get { state.analysis.performanceInfo }
        set { state.analysis.performanceInfo = newValue }
    }

    var isParallelDistillEnabled: Bool {
        get { state.analysis.isParallelDistillEnabled }
        set { state.analysis.isParallelDistillEnabled = newValue }
    }

    var distillProgress: DistillProgressUpdate? {
        get { state.analysis.distillProgress }
        set { state.analysis.distillProgress = newValue }
    }

    var partialDistillData: PartialDistillData? {
        get { state.analysis.partialDistillData }
        set { state.analysis.partialDistillData = newValue }
    }

    // MARK: - Language Properties
    var detectedLanguage: String? {
        get { state.language.detectedLanguage }
        set { state.language.detectedLanguage = newValue }
    }

    var showNonEnglishBanner: Bool {
        get { state.language.showNonEnglishBanner }
        set { state.language.showNonEnglishBanner = newValue }
    }

    var languageBannerMessage: String {
        get { state.language.bannerMessage }
        set { state.language.bannerMessage = newValue }
    }

    func latestDetectedEvents() -> [EventsData.DetectedEvent] {
        guard let id = memoId else { return [] }
        if let env: AnalyzeEnvelope<EventsData> = DIContainer.shared.analysisRepository().getAnalysisResult(for: id, mode: .events, responseType: EventsData.self) {
            return env.data.events
        }
        return []
    }

    func latestDetectedReminders() -> [RemindersData.DetectedReminder] {
        guard let id = memoId else { return [] }
        if let env: AnalyzeEnvelope<RemindersData> = DIContainer.shared.analysisRepository().getAnalysisResult(for: id, mode: .reminders, responseType: RemindersData.self) {
            return env.data.reminders
        }
        return []
    }

    var languageBannerDismissedForMemo: [UUID: Bool] {
        get { state.language.bannerDismissedForMemo }
        set { state.language.bannerDismissedForMemo = newValue }
    }

    // MARK: - Title Editing Properties
    var isRenamingTitle: Bool {
        get { state.titleEditing.isRenaming }
        set { state.titleEditing.isRenaming = newValue }
    }

    var editedTitle: String {
        get { state.titleEditing.editedTitle }
        set { state.titleEditing.editedTitle = newValue }
    }

    var currentMemoTitle: String {
        get { state.titleEditing.currentMemoTitle }
        set { state.titleEditing.currentMemoTitle = newValue }
    }

    // MARK: - Share Properties
    var showShareSheet: Bool {
        get { state.share.showShareSheet }
        set { state.share.showShareSheet = newValue }
    }

    var shareAudioEnabled: Bool {
        get { state.share.audioEnabled }
        set { state.share.audioEnabled = newValue }
    }

    var shareTranscriptionEnabled: Bool {
        get { state.share.transcriptionEnabled }
        set { state.share.transcriptionEnabled = newValue }
    }

    var shareAnalysisEnabled: Bool {
        get { state.share.analysisEnabled }
        set { state.share.analysisEnabled = newValue }
    }

    var shareAnalysisSelectedTypes: Set<DomainAnalysisType> {
        get { state.share.analysisSelectedTypes }
        set { state.share.analysisSelectedTypes = newValue }
    }

    var isPreparingShare: Bool {
        get { state.share.isPreparingShare }
        set { state.share.isPreparingShare = newValue }
    }

    // MARK: - UI Properties
    var error: SonoraError? {
        get { state.ui.error }
        set { state.ui.error = newValue }
    }

    var isLoading: Bool {
        get { state.ui.isLoading }
        set { state.ui.isLoading = newValue }
    }

    // MARK: - Operation Properties (simplified access)
    var activeOperations: [UUID] {
        get { state.operations.activeOperations }
        set { state.operations.activeOperations = newValue }
    }

    var memoOperationSummaries: [UUID] {
        get { state.operations.memoOperationSummaries }
        set { state.operations.memoOperationSummaries = newValue }
    }

    // MARK: - Deletion/UI flags
    var didDeleteMemo: Bool {
        get { state.ui.didDeleteMemo }
        set { state.ui.didDeleteMemo = newValue }
    }
}
