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

    private var effectiveReflectionQuestions: [String]? {
        data?.reflection_questions ?? partialData?.reflectionQuestions
    }

    // Use domain-deduplicated results directly
    var eventsForUI: [EventsData.DetectedEvent] { data?.events ?? partialData?.events ?? [] }
    var remindersForUI: [RemindersData.DetectedReminder] { data?.reminders ?? partialData?.reminders ?? [] }

    // MARK: - Detections (Events + Reminders)
    @StateObject private var viewModelHolder = ViewModelHolder()

    // MARK: - Action Items Host Section
    @ViewBuilder
    private var actionItemsHostSection: some View {
        ActionItemsHostSectionView(
            permissionService: viewModelHolder.vm?.permissionService ?? EventKitPermissionService(),
            visibleItems: viewModelHolder.vm?.visibleItems ?? [],
            addedRecords: viewModelHolder.vm?.addedRecords ?? [],
            isPro: isPro,
            isDetectionPending: isDetectionPending,
            showBatchSheet: Binding(get: { viewModelHolder.vm?.showBatchSheet ?? false }, set: { viewModelHolder.vm?.showBatchSheet = $0 }),
            batchInclude: Binding(get: { viewModelHolder.vm?.batchInclude ?? [] }, set: { viewModelHolder.vm?.batchInclude = $0 }),
            calendars: viewModelHolder.vm?.availableCalendars ?? [],
            reminderLists: viewModelHolder.vm?.availableReminderLists ?? [],
            defaultCalendar: viewModelHolder.vm?.defaultCalendar,
            defaultReminderList: viewModelHolder.vm?.defaultReminderList
        ) { event in
                switch event {
                case .item(let itemEvent):
                    switch itemEvent {
                    case .editToggle(let id):
                        viewModelHolder.vm?.handleEditToggle(id)
                    case .add(let item):
                        Task { @MainActor in await viewModelHolder.vm?.handleAddSingle(item) }
                    case .dismiss(let id):
                        viewModelHolder.vm?.handleDismiss(id)
                    }
                case .openBatch(let selected):
                    Task { @MainActor in await viewModelHolder.vm?.handleOpenBatch(selected: selected) }
                case .addSelected(let items, let calendar, let reminderList):
                    Task { @MainActor in await viewModelHolder.vm?.handleAddSelected(items, calendar: calendar, reminderList: reminderList) }
                case .dismissSheet:
                    break
                }
        }
        .onAppear { initializeViewModelIfNeeded() }
        .onChange(of: eventsForUI.count + remindersForUI.count) { _, _ in
            initializeViewModelIfNeeded()
            viewModelHolder.vm?.mergeIncoming(events: eventsForUI, reminders: remindersForUI)
        }
        // Conflict sheet when duplicates are found
        .sheet(isPresented: Binding(get: { viewModelHolder.vm?.showConflictSheet ?? false }, set: { viewModelHolder.vm?.showConflictSheet = $0 })) {
            EventConflictResolutionSheet(
                duplicates: viewModelHolder.vm?.conflictDuplicates ?? [],
                onProceed: { Task { @MainActor in await viewModelHolder.vm?.resolveConflictProceed() } },
                onSkip: { viewModelHolder.vm?.resolveConflictSkip() }
            )
        }
    }

    // MARK: - Reflection Questions Section

    // Reflection section extracted into component ReflectionQuestionsSectionView

    // MARK: - Detection helpers
    // Filtering and batch helpers consolidated in ActionItemDetectionState

    // MARK: - Async wrappers
    private func initializeViewModelIfNeeded() {
        if viewModelHolder.vm == nil {
            viewModelHolder.vm = ActionItemViewModel(
                memoId: memoId,
                initialEvents: eventsForUI,
                initialReminders: remindersForUI
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
