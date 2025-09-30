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

            // Performance info removed for cleaner UI

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
    @State internal var detectionItems: [ActionItemDetectionUI] = []
    @State internal var dismissedDetections: Set<UUID> = []
    @State internal var editingDetections: Set<UUID> = []
    @State internal var addedDetections: Set<UUID> = []
    @State internal var showBatchSheet: Bool = false
    @State internal var batchInclude: Set<UUID> = []
    @State internal var addedRecords: [DistillAddedRecord] = []
    @State internal var restoredAddedRecords = false
    @State internal var handledStore = DistillHandledDetectionsStore()
    @State internal var eventSources: [UUID: EventsData.DetectedEvent] = [:]
    @State internal var reminderSources: [UUID: RemindersData.DetectedReminder] = [:]
    @State internal var createdArtifacts: [UUID: DistillCreatedArtifact] = [:]
    @State internal var availableCalendars: [CalendarDTO] = []
    @State internal var availableReminderLists: [CalendarDTO] = []
    @State internal var defaultCalendar: CalendarDTO?
    @State internal var defaultReminderList: CalendarDTO?
    @State internal var calendarsLoaded = false
    @State internal var reminderListsLoaded = false
    @StateObject internal var permissionService: EventKitPermissionService = {
        if let concrete = DIContainer.shared.eventKitPermissionService() as? EventKitPermissionService {
            return concrete
        } else {
            return EventKitPermissionService()
        }
    }()

    // Unused local support types removed in favor of shared support types in ActionItemDetectionsSupport.swift

    // MARK: - Progress Section

    // Progress section extracted into component DistillProgressSectionView

    // MARK: - Summary Section

    // Summary section extracted into component DistillSummarySectionView

    // MARK: - Action Items Host Section
    @ViewBuilder
    private var actionItemsHostSection: some View {
        ActionItemsHostSectionView(
            permissionService: permissionService,
            detectionItems: $detectionItems,
            dismissedDetections: $dismissedDetections,
            addedDetections: $addedDetections,
            addedRecords: addedRecords,
            isPro: isPro,
            isDetectionPending: isDetectionPending,
            showBatchSheet: $showBatchSheet,
            batchInclude: $batchInclude,
            calendars: availableCalendars,
            reminderLists: availableReminderLists,
            defaultCalendar: defaultCalendar,
            defaultReminderList: defaultReminderList,
            onOpenBatch: { selected in
                let reviewItems = detectionItemsFiltered
                batchInclude = selected
                Task { @MainActor in
                    do { try await loadDestinationsIfNeeded(for: reviewItems); showBatchSheet = true } catch { }
                }
            },
            onEditToggle: { id in toggleEdit(id) },
            onAdd: { updated in onAddSingle(updated) },
            onDismissItem: { id in dismiss(id) },
            onAddSelected: { selected, calendar, reminderList in
                Task { @MainActor in await handleBatchAdd(selected: selected, calendar: calendar, reminderList: reminderList) }
            },
            onDismissSheet: { }
        )
        .onAppear(perform: prepareDetectionsIfNeeded)
        .onChange(of: eventsForUI.count + remindersForUI.count) { _, _ in
            prepareDetectionsIfNeeded()
        }
    }

    // MARK: - Reflection Questions Section

    // Reflection section extracted into component ReflectionQuestionsSectionView

    // MARK: - Detection helpers
    private var detectionItemsFiltered: [ActionItemDetectionUI] {
        detectionItems
            .filter { !dismissedDetections.contains($0.id) && !addedDetections.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.confidence != rhs.confidence {
                    return order(lhs.confidence) < order(rhs.confidence)
                }
                // Earlier dates first if both present
                if let ld = lhs.suggestedDate, let rd = rhs.suggestedDate {
                    return ld < rd
                }
                return false
            }
    }
    private func order(_ c: ActionItemConfidence) -> Int { c == .high ? 0 : (c == .medium ? 1 : 2) }
    private var reviewCount: Int { detectionItemsFiltered.count }
    private func openBatchReview() {
        let reviewItems = detectionItemsFiltered
        batchInclude = Set(reviewItems.map { $0.id })
        Task { @MainActor in
            do { try await loadDestinationsIfNeeded(for: reviewItems); showBatchSheet = true } catch { }
        }
    }
    // prepareDetectionsIfNeeded moved to DistillResultView+Detections.swift
    // toggleEdit moved to DistillResultView+Detections.swift
    // dismiss moved to DistillResultView+Detections.swift
    // onAddSingle moved to DistillResultView+Detections.swift
    // undoAdd moved to DistillResultView+Detections.swift
    // merge moved to DistillResultView+Detections.swift

    // updateDetection moved to DistillResultView+Detections.swift

    // Key used to persist "handled" detections.
    // Use the detection's own stable sourceId (UUID from detection payload) for uniqueness.
    // detectionKey moved to DistillResultView+Detections.swift

    // Removed duplicate handleSingleAdd/handleUndo (kept in DistillResultView+Detections.swift)

    // setProcessing moved to DistillResultView+Detections.swift

    // addEvent moved to DistillResultView+Detections.swift

    // addReminder moved to DistillResultView+Detections.swift

    // handleBatchAdd moved to DistillResultView+Detections.swift

    // batchAddEvents moved to DistillResultView+Detections.swift

    // batchAddReminders moved to DistillResultView+Detections.swift

    // buildEventPayload/buildReminderPayload moved to DistillDetectionsUtils

    // loadDestinationsIfNeeded moved to DistillResultView+Detections.swift

    // ensureCalendarPermission moved to DistillResultView+Detections.swift

    // ensureReminderPermission moved to DistillResultView+Detections.swift

    // appendAddedMessage moved to DistillResultView+Detections.swift

    private var shouldShowPermissionExplainer: Bool {
        // Show explainer if either permission not determined or denied/restricted
        let cal = permissionService.calendarPermissionState
        let rem = permissionService.reminderPermissionState
        return !(cal.isAuthorized && rem.isAuthorized)
    }

    // eventLine, reminderLine, formatShortDate moved to DistillDetectionsUtils

    // dedupeDetections moved to DistillDetectionsUtils

    // MARK: - Placeholder Views

    // Placeholders extracted into dedicated components

    // Performance info removed — simplified progress UI (no technical details)

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
