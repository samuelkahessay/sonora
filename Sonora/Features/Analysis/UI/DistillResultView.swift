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
    @StateObject internal var permissionService: EventKitPermissionService = {
        if let concrete = DIContainer.shared.eventKitPermissionService() as? EventKitPermissionService {
            return concrete
        } else {
            return EventKitPermissionService()
        }
    }()

    // MARK: - Action Items Host Section
    @ViewBuilder
    private var actionItemsHostSection: some View {
        ActionItemsHostSectionView(
            permissionService: permissionService,
            visibleItems: detection.visibleItems,
            addedRecords: detection.addedRecords,
            isPro: isPro,
            isDetectionPending: isDetectionPending,
            showBatchSheet: $detection.showBatchSheet,
            batchInclude: $detection.batchInclude,
            calendars: detection.availableCalendars,
            reminderLists: detection.availableReminderLists,
            defaultCalendar: detection.defaultCalendar,
            defaultReminderList: detection.defaultReminderList,
            onOpenBatch: { selected in
                let reviewItems = detection.visibleItems
                detection.batchInclude = selected
                Task { @MainActor in await openBatchReview(reviewItems) }
            },
            onEditToggle: { id in detection.toggleEdit(id) },
            onAdd: { updated in Task { @MainActor in await addSingle(updated) } },
            onDismissItem: { id in detection.dismiss(id) },
            onAddSelected: { selected, calendar, reminderList in
                Task { @MainActor in await handleBatchAdd(selected: selected, calendar: calendar, reminderList: reminderList) }
            },
            onDismissSheet: { }
        )
        .onAppear {
            detection.mergeFrom(events: eventsForUI, reminders: remindersForUI, memoId: memoId)
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
            let dest = try await detection.fetchDestinationsIfNeeded(for: reviewItems)
            if dest.didLoadCalendars { detection.availableCalendars = dest.calendars; detection.defaultCalendar = dest.defaultCalendar; detection.calendarsLoaded = true }
            if dest.didLoadReminderLists { detection.availableReminderLists = dest.reminderLists; detection.defaultReminderList = dest.defaultReminderList; detection.reminderListsLoaded = true }
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
                try await detection.ensureCalendarPermission(permissionService: permissionService)
                let dest = try await detection.fetchDestinationsIfNeeded(for: [item])
                if dest.didLoadCalendars { detection.availableCalendars = dest.calendars; detection.defaultCalendar = dest.defaultCalendar; detection.calendarsLoaded = true }
                let createdId = try await detection.createEvent(for: item, in: detection.defaultCalendar ?? detection.availableCalendars.first)
                detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .event, identifier: createdId)
            case .reminder:
                try await detection.ensureReminderPermission(permissionService: permissionService)
                let dest = try await detection.fetchDestinationsIfNeeded(for: [item])
                if dest.didLoadReminderLists { detection.availableReminderLists = dest.reminderLists; detection.defaultReminderList = dest.defaultReminderList; detection.reminderListsLoaded = true }
                let createdId = try await detection.createReminder(for: item, in: detection.defaultReminderList ?? detection.availableReminderLists.first)
                detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .reminder, identifier: createdId)
            }
            detection.added.insert(item.id)
            detection.appendAddedMessage(for: item)
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
                try await detection.ensureCalendarPermission(permissionService: permissionService)
                let dest = try await detection.fetchDestinationsIfNeeded(for: eventItems)
                if dest.didLoadCalendars { detection.availableCalendars = dest.calendars; detection.defaultCalendar = dest.defaultCalendar; detection.calendarsLoaded = true }
                let destination = calendar ?? detection.defaultCalendar ?? detection.availableCalendars.first
                guard let destination else { throw EventKitError.calendarNotFound(identifier: "default") }
                for item in eventItems {
                    let id = try await detection.createEvent(for: item, in: destination)
                    detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .event, identifier: id)
                    detection.added.insert(item.id)
                    detection.appendAddedMessage(for: item)
                }
            }
            if !reminderItems.isEmpty {
                try await detection.ensureReminderPermission(permissionService: permissionService)
                let dest = try await detection.fetchDestinationsIfNeeded(for: reminderItems)
                if dest.didLoadReminderLists { detection.availableReminderLists = dest.reminderLists; detection.defaultReminderList = dest.defaultReminderList; detection.reminderListsLoaded = true }
                let destination = reminderList ?? detection.defaultReminderList ?? detection.availableReminderLists.first
                guard let destination else { throw EventKitError.reminderListNotFound(identifier: "default") }
                for item in reminderItems {
                    let id = try await detection.createReminder(for: item, in: destination)
                    detection.createdArtifacts[item.id] = DistillCreatedArtifact(kind: .reminder, identifier: id)
                    detection.added.insert(item.id)
                    detection.appendAddedMessage(for: item)
                }
            }
            HapticManager.shared.playSuccess()
        } catch {
            HapticManager.shared.playError()
        }
    }

    private var shouldShowPermissionExplainer: Bool {
        // Show explainer if either permission not determined or denied/restricted
        let cal = permissionService.calendarPermissionState
        let rem = permissionService.reminderPermissionState
        return !(cal.isAuthorized && rem.isAuthorized)
    }

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
