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
                SummaryPlaceholderView()
            }

            // Action Items Section (host both tasks and detections)
            actionItemsHostSection

            // Reflection Questions Section
            if let reflectionQuestions = effectiveReflectionQuestions, !reflectionQuestions.isEmpty {
                ReflectionQuestionsSectionView(questions: reflectionQuestions)
            } else if isShowingProgress {
                ReflectionQuestionsPlaceholderView()
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

    private var dedupedDetectionResults: ([EventsData.DetectedEvent], [RemindersData.DetectedReminder]) {
        dedupeDetections(
            events: data?.events ?? partialData?.events ?? [],
            reminders: data?.reminders ?? partialData?.reminders ?? []
        )
    }

    var eventsForUI: [EventsData.DetectedEvent] { dedupedDetectionResults.0 }
    var remindersForUI: [RemindersData.DetectedReminder] { dedupedDetectionResults.1 }

    // MARK: - Detections (Events + Reminders)
    @State private var detection = ActionItemDetectionState()
    @StateObject private var coordinator = ActionItemCoordinator()

    // MARK: - Action Items Host Section
    @ViewBuilder
    private var actionItemsHostSection: some View {
        ActionItemsHostSectionView(
            permissionService: coordinator.permissionService,
            visibleItems: detection.visibleItems,
            addedRecords: coordinator.addedRecords,
            isPro: isPro,
            isDetectionPending: isDetectionPending,
            showBatchSheet: $detection.showBatchSheet,
            batchInclude: $detection.batchInclude,
            calendars: detection.availableCalendars,
            reminderLists: detection.availableReminderLists,
            defaultCalendar: detection.defaultCalendar,
            defaultReminderList: detection.defaultReminderList,
            onEvent: { event in
                switch event {
                case .item(let itemEvent):
                    switch itemEvent {
                    case .editToggle(let id):
                        detection.toggleEdit(id)
                    case .add(let item):
                        Task { @MainActor in await addSingle(item) }
                    case .dismiss(let id):
                        detection.dismiss(id)
                    }
                case .openBatch(let selected):
                    detection.batchInclude = selected
                    let reviewItems = detection.visibleItems
                    Task { @MainActor in await openBatchReview(reviewItems) }
                case .addSelected(let items, let calendar, let reminderList):
                    Task { @MainActor in await handleBatchAdd(selected: items, calendar: calendar, reminderList: reminderList) }
                case .dismissSheet:
                    break
                }
            }
        )
        .onAppear {
            detection.mergeFrom(events: eventsForUI, reminders: remindersForUI, memoId: memoId)
            coordinator.restoreHandled(for: memoId)
        }
        .onChange(of: eventsForUI.count + remindersForUI.count) { _, _ in
            detection.mergeFrom(events: eventsForUI, reminders: remindersForUI, memoId: memoId)
        }
    }

    // MARK: - Reflection Questions Section

    // Reflection section extracted into component ReflectionQuestionsSectionView

    // MARK: - Detection helpers
    // Filtering and batch helpers consolidated in ActionItemDetectionState

    // MARK: - Async wrappers
    @MainActor
    private func openBatchReview(_ reviewItems: [ActionItemDetectionUI]) async {
        do {
            let res = try await coordinator.loadDestinationsIfNeeded(for: reviewItems, calendarsLoaded: detection.calendarsLoaded, reminderListsLoaded: detection.reminderListsLoaded)
            if res.didLoadCalendars { detection.availableCalendars = coordinator.availableCalendars; detection.defaultCalendar = coordinator.defaultCalendar; detection.calendarsLoaded = true }
            if res.didLoadReminderLists { detection.availableReminderLists = coordinator.availableReminderLists; detection.defaultReminderList = coordinator.defaultReminderList; detection.reminderListsLoaded = true }
            detection.showBatchSheet = true
        } catch { }
    }

    @MainActor
    private func addSingle(_ item: ActionItemDetectionUI) async {
        detection.update(item)
        detection.setProcessing(item.id, to: true)
        defer { detection.setProcessing(item.id, to: false) }
        do {
            switch item.kind {
            case .event:
                try await coordinator.ensureCalendarPermission()
                let res = try await coordinator.loadDestinationsIfNeeded(for: [item], calendarsLoaded: detection.calendarsLoaded, reminderListsLoaded: detection.reminderListsLoaded)
                if res.didLoadCalendars { detection.availableCalendars = coordinator.availableCalendars; detection.defaultCalendar = coordinator.defaultCalendar; detection.calendarsLoaded = true }
                guard let base = detection.eventSources[item.id] else { throw EventKitError.invalidEventData(field: "event source missing") }
                let createdId = try await coordinator.createEvent(for: item, base: base, in: detection.defaultCalendar ?? detection.availableCalendars.first)
                detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .event, identifier: createdId)
            case .reminder:
                try await coordinator.ensureReminderPermission()
                let res = try await coordinator.loadDestinationsIfNeeded(for: [item], calendarsLoaded: detection.calendarsLoaded, reminderListsLoaded: detection.reminderListsLoaded)
                if res.didLoadReminderLists { detection.availableReminderLists = coordinator.availableReminderLists; detection.defaultReminderList = coordinator.defaultReminderList; detection.reminderListsLoaded = true }
                guard let base = detection.reminderSources[item.id] else { throw EventKitError.invalidEventData(field: "reminder source missing") }
                let createdId = try await coordinator.createReminder(for: item, base: base, in: detection.defaultReminderList ?? detection.availableReminderLists.first)
                detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .reminder, identifier: createdId)
            }
            detection.added.insert(item.id)
            let date: Date? = {
                if let d = item.suggestedDate { return d }
                switch item.kind {
                case .event: return detection.eventSources[item.id]?.startDate
                case .reminder: return detection.reminderSources[item.id]?.dueDate
                }
            }()
            let rec = coordinator.makeAddedRecord(for: item, date: date)
            coordinator.upsertAndPersist(record: rec, memoId: item.memoId ?? memoId)
            HapticManager.shared.playSuccess()
        } catch {
            HapticManager.shared.playError()
        }
    }

    @MainActor
    private func handleBatchAdd(selected: [ActionItemDetectionUI], calendar: CalendarDTO?, reminderList: CalendarDTO?) async {
        guard !selected.isEmpty else { return }
        selected.forEach { detection.update($0) }
        let ids = selected.map { $0.id }
        ids.forEach { detection.setProcessing($0, to: true) }
        defer { ids.forEach { detection.setProcessing($0, to: false) } }

        let eventItems = selected.filter { $0.kind == .event }
        let reminderItems = selected.filter { $0.kind == .reminder }
        do {
            if !eventItems.isEmpty {
                try await coordinator.ensureCalendarPermission()
                let res = try await coordinator.loadDestinationsIfNeeded(for: eventItems, calendarsLoaded: detection.calendarsLoaded, reminderListsLoaded: detection.reminderListsLoaded)
                if res.didLoadCalendars { detection.availableCalendars = coordinator.availableCalendars; detection.defaultCalendar = coordinator.defaultCalendar; detection.calendarsLoaded = true }
                let destination = calendar ?? detection.defaultCalendar ?? detection.availableCalendars.first
                guard let destination else { throw EventKitError.calendarNotFound(identifier: "default") }
                for item in eventItems {
                    guard let base = detection.eventSources[item.id] else { continue }
                    let id = try await coordinator.createEvent(for: item, base: base, in: destination)
                    detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .event, identifier: id)
                    detection.added.insert(item.id)
                    let date = item.suggestedDate ?? base.startDate
                    let rec = coordinator.makeAddedRecord(for: item, date: date)
                    coordinator.upsertAndPersist(record: rec, memoId: item.memoId ?? memoId)
                }
            }
            if !reminderItems.isEmpty {
                try await coordinator.ensureReminderPermission()
                let res = try await coordinator.loadDestinationsIfNeeded(for: reminderItems, calendarsLoaded: detection.calendarsLoaded, reminderListsLoaded: detection.reminderListsLoaded)
                if res.didLoadReminderLists { detection.availableReminderLists = coordinator.availableReminderLists; detection.defaultReminderList = coordinator.defaultReminderList; detection.reminderListsLoaded = true }
                let destination = reminderList ?? detection.defaultReminderList ?? detection.availableReminderLists.first
                guard let destination else { throw EventKitError.reminderListNotFound(identifier: "default") }
                for item in reminderItems {
                    guard let base = detection.reminderSources[item.id] else { continue }
                    let id = try await coordinator.createReminder(for: item, base: base, in: destination)
                    detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .reminder, identifier: id)
                    detection.added.insert(item.id)
                    let date = item.suggestedDate ?? base.dueDate
                    let rec = coordinator.makeAddedRecord(for: item, date: date)
                    coordinator.upsertAndPersist(record: rec, memoId: item.memoId ?? memoId)
                }
            }
            HapticManager.shared.playSuccess()
        } catch {
            HapticManager.shared.playError()
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
