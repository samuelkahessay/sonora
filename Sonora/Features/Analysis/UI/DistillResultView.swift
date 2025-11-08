import SwiftUI

/// Comprehensive view for displaying Distill analysis results
/// Shows summary, action items, themes, and reflection questions in a mentor-like format
/// Supports progressive rendering of partial data as components complete
import UIKit

struct DistillResultView: View {
    let data: DistillData?
    let envelope: AnalyzeEnvelope<DistillData>?
    let partialData: PartialDistillData?
    let progress: DistillProgressUpdate?
    let memoId: UUID?
    // Pro gating (Action Items: detection visible to all; adds gated later)
    private var isPro: Bool { DIContainer.shared.storeKitService().isPro }
    @State private var showPaywall: Bool = false
    @SwiftUI.Environment(\.diContainer)
    var container: DIContainer

    // Convenience initializers for backward compatibility
    init(data: DistillData, envelope: AnalyzeEnvelope<DistillData>, memoId: UUID? = nil) {
        self.data = data
        self.envelope = envelope
        self.partialData = nil
        self.progress = nil
        self.memoId = memoId
    }

    init(partialData: PartialDistillData, progress: DistillProgressUpdate, memoId: UUID? = nil) {
        self.data = partialData.toDistillData()
        self.envelope = nil
        self.partialData = partialData
        self.progress = progress
        self.memoId = memoId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Progress indicator for parallel processing
            if let progress = progress, progress.completedComponents < progress.totalComponents {
                DistillProgressSectionView(progress: progress)
            }

            // Summary Section
            if let summary = effectiveSummary {
                DistillSummarySectionView(summary: summary)
            } else if isShowingProgress {
                SummarySkeleton()
            }

            // Patterns & Connections Section
            if let patterns = effectivePatterns, !patterns.isEmpty {
                PatternsSectionView(patterns: patterns)
            }

            // Action Items Section (host both tasks and detections)
            actionItemsHostSection

            // Reflection Questions Section
            if let reflectionQuestions = effectiveReflectionQuestions, !reflectionQuestions.isEmpty {
                ReflectionQuestionsSectionView(questions: reflectionQuestions)
            } else if isShowingProgress {
                ReflectionQuestionsSkeleton()
            }

            // Copy results action (also triggers smart transcript expand via notification)
            copyAction
        }
        .textSelection(.enabled)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear {
            Logger.shared.debug(
                "ActionItems.InitVM.TopAppear",
                category: .viewModel,
                context: LogContext(additionalInfo: [
                    "memoId": memoId?.uuidString ?? "nil",
                    "eventsForUI": eventsForUI.count,
                    "remindersForUI": remindersForUI.count,
                    "isDetectionPending": isDetectionPending
                ])
            )
            initializeViewModelIfNeeded()
        }
    }

    // MARK: - Computed Properties

    private var isShowingProgress: Bool {
        progress != nil && partialData != nil
    }

    private var isProgressComplete: Bool {
        guard let p = progress else { return false }
        return p.completedComponents >= p.totalComponents
    }

    @ViewBuilder
    private var copyAction: some View {
        HStack {
            Spacer()
            Button(action: {
                let text = buildCopyText()
                UIPasteboard.general.string = text
                HapticManager.shared.playLightImpact()
                NotificationCenter.default.post(name: Notification.Name("AnalysisCopyTriggered"), object: nil)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Copy analysis results")
        }
    }

    private var effectiveSummary: String? {
        data?.summary ?? partialData?.summary
    }

    private var effectivePatterns: [DistillData.Pattern]? {
        data?.patterns ?? partialData?.patterns
    }

    private var effectiveReflectionQuestions: [String]? {
        data?.reflection_questions ?? partialData?.reflectionQuestions
    }

    // Use domain-deduplicated results directly
    // Note: Repository fallback removed - async getAnalysisResult can't be called from computed property
    // TODO: Refactor to load repository data asynchronously in onAppear
    var eventsForUI: [EventsData.DetectedEvent] {
        if let ev = data?.events, !ev.isEmpty { return ev }
        if let ev = partialData?.events, !ev.isEmpty { return ev }
        return []
    }
    // Note: Repository fallback removed - async getAnalysisResult can't be called from computed property
    // TODO: Refactor to load repository data asynchronously in onAppear
    var remindersForUI: [RemindersData.DetectedReminder] {
        if let rem = data?.reminders, !rem.isEmpty { return rem }
        if let rem = partialData?.reminders, !rem.isEmpty { return rem }
        return []
    }

    // MARK: - Detections (Events + Reminders)
    @StateObject private var viewModelHolder = ViewModelHolder()

    // MARK: - Action Items Host Section
    @ViewBuilder
    private var actionItemsHostSection: some View {
        if let vm = viewModelHolder.vm {
            ActionItemsHostObservedSection(
                vm: vm,
                isPro: isPro,
                isDetectionPending: isDetectionPending
            )
            .onAppear {
                Logger.shared.info(
                    "ActionItems.HostAppeared",
                    category: .viewModel,
                    context: LogContext(additionalInfo: [
                        "memoId": memoId?.uuidString ?? "nil",
                        "eventsForUI": eventsForUI.count,
                        "remindersForUI": remindersForUI.count,
                        "isDetectionPending": isDetectionPending
                    ])
                )
            }
            .onChange(of: eventsForUI.count + remindersForUI.count) { _, _ in
                vm.mergeIncoming(events: eventsForUI, reminders: remindersForUI)
            }
        } else {
            // Initialize lazily and render nothing until VM exists
            EmptyView()
                .onAppear {
                    Logger.shared.debug(
                        "ActionItems.InitVM.Request",
                        category: .viewModel,
                        context: LogContext(additionalInfo: [
                            "memoId": memoId?.uuidString ?? "nil",
                            "eventsForUI": eventsForUI.count,
                            "remindersForUI": remindersForUI.count,
                            "isDetectionPending": isDetectionPending
                        ])
                    )
                    initializeViewModelIfNeeded()
                }
        }
    }

    // MARK: - Reflection Questions Section

    // Reflection section extracted into component ReflectionQuestionsSectionView

    // MARK: - Detection helpers
    // Filtering and batch helpers consolidated in ActionItemDetectionState

    // MARK: - Async wrappers
    private func initializeViewModelIfNeeded() {
        if viewModelHolder.vm == nil {
            Logger.shared.debug(
                "ActionItems.InitVM.Build",
                category: .viewModel,
                context: LogContext(additionalInfo: [
                    "memoId": memoId?.uuidString ?? "nil",
                    "eventsForUI": eventsForUI.count,
                    "remindersForUI": remindersForUI.count,
                    "isDetectionPending": isDetectionPending
                ])
            )
            viewModelHolder.vm = ActionItemViewModel(
                memoId: memoId,
                initialEvents: eventsForUI,
                initialReminders: remindersForUI
            )
            Logger.shared.info(
                "ActionItems.InitVM.Built",
                category: .viewModel,
                context: LogContext(additionalInfo: [
                    "memoId": memoId?.uuidString ?? "nil"
                ])
            )
        }
    }

    // Removed local permission explainer; handled in ActionItemsHostSectionView

    // MARK: - Placeholder Views

    // Build a concatenated text representation for copying
    private func buildCopyText() -> String {
        var parts: [String] = []
        if let s = effectiveSummary, !s.isEmpty {
            parts.append("Summary:\n" + s)
        }
        // Patterns & Connections
        if let patterns = effectivePatterns, !patterns.isEmpty {
            var patternLines: [String] = ["Patterns & Connections:"]
            for (index, pattern) in patterns.enumerated() {
                patternLines.append("\(index + 1). \(pattern.theme)")
                patternLines.append("   \(pattern.description)")
                if let relatedMemos = pattern.relatedMemos, !relatedMemos.isEmpty {
                    patternLines.append("   Related memos:")
                    for memo in relatedMemos.prefix(3) {
                        let timeStr = memo.daysAgo.map { "(\($0) days ago)" } ?? ""
                        patternLines.append("   • \(memo.title) \(timeStr)")
                    }
                }
            }
            parts.append(patternLines.joined(separator: "\n"))
        }
        // Key Themes intentionally omitted from Distill (Themes is a separate mode)
        if let questions = effectiveReflectionQuestions, !questions.isEmpty {
            let list = questions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            parts.append("Reflection Questions:\n" + list)
        }
        let events = eventsForUI
        let reminders = remindersForUI
        if !events.isEmpty || !reminders.isEmpty {
            var lines: [String] = []
            if !events.isEmpty {
                lines.append("Events:")
                lines.append(contentsOf: events.map(eventLine))
            }
            if !reminders.isEmpty {
                lines.append("Reminders:")
                lines.append(contentsOf: reminders.map(reminderLine))
            }
            parts.append(lines.joined(separator: "\n"))
        } else if !(isShowingProgress && !isProgressComplete) {
            // Only append a "none" message when not mid-stream
            parts.append("Events & Reminders:\nNo events or reminders detected")
        }
        return parts.joined(separator: "\n\n")
    }

    // Detection is pending if we are streaming and haven't received any detection payload yet
    private var isDetectionPending: Bool {
        guard isShowingProgress else { return false }
        return partialData?.events == nil && partialData?.reminders == nil && !isProgressComplete
    }

}

// Helper to own a @StateObject VM while allowing optional init in body
private final class ViewModelHolder: ObservableObject {
    @Published var vm: ActionItemViewModel?
}

private extension DistillResultView { }

// MARK: - Observed wrapper to react to VM changes
private struct ActionItemsHostObservedSection: View {
    @ObservedObject var vm: ActionItemViewModel
    let isPro: Bool
    let isDetectionPending: Bool

    var body: some View {
        ActionItemsHostSectionView(
            permissionService: vm.permissionService,
            visibleItems: vm.visibleItems,
            addedRecords: vm.addedRecords,
            isPro: isPro,
            isDetectionPending: isDetectionPending,
            showBatchSheet: $vm.showBatchSheet,
            batchInclude: $vm.batchInclude,
            calendars: vm.availableCalendars,
            reminderLists: vm.availableReminderLists,
            defaultCalendar: vm.defaultCalendar,
            defaultReminderList: vm.defaultReminderList
        ) { event in
            switch event {
            case .item(let itemEvent):
                switch itemEvent {
                case .editToggle(let id):
                    vm.handleEditToggle(id)
                case .add(let item):
                    Task { @MainActor in await vm.handleAddSingle(item) }
                case .dismiss(let id):
                    vm.handleDismiss(id)
                }
            case .openBatch(let selected):
                Task { @MainActor in await vm.handleOpenBatch(selected: selected) }
            case .addSelected(let items, let calendar, let reminderList):
                Task { @MainActor in await vm.handleAddSelected(items, calendar: calendar, reminderList: reminderList) }
            case .dismissSheet:
                break
            }
        }
        // Conflict sheet when duplicates are found
        .sheet(isPresented: $vm.showConflictSheet) {
            EventConflictResolutionSheet(
                duplicates: vm.conflictDuplicates,
                onProceed: { Task { @MainActor in await vm.resolveConflictProceed() } },
                onSkip: { vm.resolveConflictSkip() }
            )
        }
    }
}
