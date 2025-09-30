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
    @SwiftUI.Environment(\.diContainer) private var container: DIContainer

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
                progressSection(progress)
            }

            // Summary Section
            if let summary = effectiveSummary {
                summarySection(summary)
            } else if isShowingProgress {
                summaryPlaceholder
            }

            // Action Items Section (host both tasks and detections)
            actionItemsHostSection

            // Reflection Questions Section
            if let reflectionQuestions = effectiveReflectionQuestions, !reflectionQuestions.isEmpty {
                reflectionQuestionsSection(reflectionQuestions)
            } else if isShowingProgress {
                reflectionQuestionsPlaceholder
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
        return data?.summary ?? partialData?.summary
    }

    private var effectiveReflectionQuestions: [String]? {
        return data?.reflection_questions ?? partialData?.reflectionQuestions
    }

    private var dedupedDetectionResults: ([EventsData.DetectedEvent], [RemindersData.DetectedReminder]) {
        dedupeDetections(
            events: data?.events ?? partialData?.events ?? [],
            reminders: data?.reminders ?? partialData?.reminders ?? []
        )
    }

    private var eventsForUI: [EventsData.DetectedEvent] { dedupedDetectionResults.0 }
    private var remindersForUI: [RemindersData.DetectedReminder] { dedupedDetectionResults.1 }

    // MARK: - Detections (Events + Reminders)
    @State private var detectionItems: [ActionItemDetectionUI] = []
    @State private var dismissedDetections: Set<UUID> = []
    @State private var editingDetections: Set<UUID> = []
    @State private var addedDetections: Set<UUID> = []
    @State private var showBatchSheet: Bool = false
    @State private var batchInclude: Set<UUID> = []
    @State private var addedRecords: [AddedRecord] = []
    @State private var restoredAddedRecords = false
    @State private var handledStore = HandledDetectionsStore()
    @State private var eventSources: [UUID: EventsData.DetectedEvent] = [:]
    @State private var reminderSources: [UUID: RemindersData.DetectedReminder] = [:]
    @State private var createdArtifacts: [UUID: CreatedArtifact] = [:]
    @State private var availableCalendars: [CalendarDTO] = []
    @State private var availableReminderLists: [CalendarDTO] = []
    @State private var defaultCalendar: CalendarDTO?
    @State private var defaultReminderList: CalendarDTO?
    @State private var calendarsLoaded = false
    @State private var reminderListsLoaded = false
    @StateObject private var permissionService = DIContainer.shared.eventKitPermissionService() as! EventKitPermissionService

    private struct CreatedArtifact: Equatable {
        let kind: ActionItemDetectionKind
        let identifier: String
    }
    private struct AddedRecord: Identifiable, Equatable {
        let id: String
        let text: String
    }

    // Persistently remember which detections were added (per memo), so they don't reappear
    private struct HandledDetectionsStore {
        struct Entry: Equatable { let id: String; let message: String }

        private var cache: [UUID: [Entry]] = [:]
        private let defaults = UserDefaults.standard

        private func storageKey(_ memoId: UUID) -> String { "handledDetections." + memoId.uuidString }

        mutating func entries(for memoId: UUID) -> [Entry] {
            if let cached = cache[memoId] { return cached }
            guard let raw = defaults.array(forKey: storageKey(memoId)) as? [[String: String]] else {
                cache[memoId] = []
                return []
            }
            let entries = raw.compactMap { dict -> Entry? in
                guard let id = dict["id"], let message = dict["message"] else { return nil }
                return Entry(id: id, message: message)
            }
            cache[memoId] = entries
            return entries
        }

        mutating func add(_ key: String, message: String, for memoId: UUID) {
            var entries = entries(for: memoId)
            if let idx = entries.firstIndex(where: { $0.id == key }) {
                entries[idx] = Entry(id: key, message: message)
            } else {
                entries.append(Entry(id: key, message: message))
            }
            cache[memoId] = entries
            defaults.set(entries.map { ["id": $0.id, "message": $0.message] }, forKey: storageKey(memoId))
        }

        mutating func remove(_ key: String, for memoId: UUID) {
            var entries = entries(for: memoId)
            if let idx = entries.firstIndex(where: { $0.id == key }) {
                entries.remove(at: idx)
                cache[memoId] = entries
                defaults.set(entries.map { ["id": $0.id, "message": $0.message] }, forKey: storageKey(memoId))
            }
        }

        mutating func messages(for memoId: UUID) -> [Entry] {
            entries(for: memoId)
        }

        mutating func contains(_ key: String, for memoId: UUID) -> Bool {
            entries(for: memoId).contains { $0.id == key }
        }
    }

    // MARK: - Progress Section

    @ViewBuilder
    private func progressSection(_ progress: DistillProgressUpdate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Processing Components (\(progress.completedComponents)/\(progress.totalComponents))")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if let latestComponent = progress.latestComponent {
                    Text(latestComponent.displayName)
                        .font(.caption)
                        .foregroundColor(.semantic(.success))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.semantic(.success).opacity(0.1))
                        .cornerRadius(4)
                }
            }

            ProgressView(value: progress.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .semantic(.brandPrimary)))
        }
        .padding(12)
        .background(Color.semantic(.brandPrimary).opacity(0.05))
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.3), value: progress.completedComponents)
    }

    // MARK: - Summary Section

    @ViewBuilder
    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }

            Text(summary)
                .font(.body)
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: - Action Items Host Section
    @ViewBuilder
    private var actionItemsHostSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if shouldShowPermissionExplainer {
                PermissionExplainerCard(
                    permissions: permissionService,
                    onOpenSettings: { DIContainer.shared.systemNavigator().openSettings(completion: nil) }
                )
            }
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Action Items")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if reviewCount > 1 {
                    Button("Review & Add All (\(reviewCount))") { openBatchReview() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }

            if !addedRecords.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(addedRecords) { rec in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.semantic(.success))
                            Text(rec.text)
                                .font(.footnote)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                    }
                }
                .padding(10)
                .background(Color.semantic(.fillSecondary))
                .cornerRadius(8)
            }

            // Detection Cards (visible to all; adds gated by Pro later)
            if !detectionItemsFiltered.isEmpty {
                VStack(spacing: 12) {
                    ForEach(detectionItemsFiltered) { m in
                        ActionItemDetectionCard(
                            model: m,
                            isPro: isPro,
                            onAdd: { updated in onAddSingle(updated) },
                            onEditToggle: { id in toggleEdit(id) },
                            onDismiss: { id in dismiss(id) }
                        )
                    }
                }
            } else if isDetectionPending {
                HStack(spacing: 8) {
                    LoadingIndicator(size: .small)
                    Text("Detecting events & reminders…")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
                .padding(.vertical, 4)
            } else if addedRecords.isEmpty {
                Text("No events or reminders detected")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            }
        }
        .onAppear(perform: prepareDetectionsIfNeeded)
        .onChange(of: eventsForUI.count + remindersForUI.count) { _, _ in
            prepareDetectionsIfNeeded()
        }
        .sheet(isPresented: $showBatchSheet) {
            BatchAddActionItemsSheet(
                items: $detectionItems,
                include: $batchInclude,
                isPro: isPro,
                calendars: availableCalendars,
                reminderLists: availableReminderLists,
                defaultCalendar: defaultCalendar,
                defaultReminderList: defaultReminderList,
                onEdit: { id in toggleEdit(id) },
                onAddSelected: { selected, calendar, reminderList in
                    showBatchSheet = false
                    Task { @MainActor in await handleBatchAdd(selected: selected, calendar: calendar, reminderList: reminderList) }
                },
                onDismiss: { showBatchSheet = false }
            )
        }
    }

    // MARK: - Reflection Questions Section

    @ViewBuilder
    private func reflectionQuestionsSection(_ questions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.warning))
                Text("Reflection Questions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textPrimary))
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.semantic(.textSecondary))
                            .frame(minWidth: 20)

                        Text(question)
                            .font(.callout)
                            .foregroundColor(.semantic(.textPrimary))
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.semantic(.warning).opacity(0.05),
                                Color.semantic(.warning).opacity(0.02)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Detection helpers
    private var detectionItemsFiltered: [ActionItemDetectionUI] {
        detectionItems
            .filter { !dismissedDetections.contains($0.id) && !addedDetections.contains($0.id) }
            .sorted(by: { lhs, rhs in
                if lhs.confidence != rhs.confidence {
                    return order(lhs.confidence) < order(rhs.confidence)
                }
                // Earlier dates first if both present
                if let ld = lhs.suggestedDate, let rd = rhs.suggestedDate {
                    return ld < rd
                }
                return false
            })
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
    private func prepareDetectionsIfNeeded() {
        let events = eventsForUI
        let reminders = remindersForUI
        let existingBySource = Dictionary(uniqueKeysWithValues: detectionItems.map { ($0.sourceId, $0) })

        var mergedItems: [ActionItemDetectionUI] = []
        var newEventSources: [UUID: EventsData.DetectedEvent] = [:]
        var newReminderSources: [UUID: RemindersData.DetectedReminder] = [:]

        if !restoredAddedRecords {
            if let memoId {
                let stored = handledStore.messages(for: memoId)
                addedRecords = stored.map { AddedRecord(id: $0.id, text: $0.message) }
            } else {
                addedRecords = []
            }
            restoredAddedRecords = true
        }

        for event in events {
            var baseUI = ActionItemDetectionUI.fromEvent(event)
            if baseUI.memoId == nil { baseUI.memoId = memoId ?? event.memoId }
            let merged = merge(base: baseUI, existing: existingBySource[event.id])
            mergedItems.append(merged)
            newEventSources[merged.id] = event
        }

        for reminder in reminders {
            var baseUI = ActionItemDetectionUI.fromReminder(reminder)
            if baseUI.memoId == nil { baseUI.memoId = memoId ?? reminder.memoId }
            let merged = merge(base: baseUI, existing: existingBySource[reminder.id])
            mergedItems.append(merged)
            newReminderSources[merged.id] = reminder
        }

        // Filter out items previously added (persisted per memo)
        let filtered = mergedItems.filter { ui in
            guard let memoId = ui.memoId else { return true }
            let key = detectionKey(for: ui)
            return !handledStore.contains(key, for: memoId)
        }

        detectionItems = filtered
        eventSources = newEventSources
        reminderSources = newReminderSources
    }
    private func toggleEdit(_ id: UUID) {
        if let idx = detectionItems.firstIndex(where: { $0.id == id }) {
            detectionItems[idx].isEditing.toggle()
        }
    }
    private func dismiss(_ id: UUID) {
        dismissedDetections.insert(id)
        if let idx = detectionItems.firstIndex(where: { $0.id == id }) {
            detectionItems[idx].isDismissed = true
        }
    }
    private func onAddSingle(_ updatedModel: ActionItemDetectionUI) {
        updateDetection(updatedModel)
        Task { @MainActor in await handleSingleAdd(updatedModel) }
    }
    private func undoAdd(_ id: UUID) {
        Task { @MainActor in await handleUndo(id: id) }
    }
    private func merge(base: ActionItemDetectionUI, existing: ActionItemDetectionUI?) -> ActionItemDetectionUI {
        guard let existing else { return base }
        return ActionItemDetectionUI(
            id: existing.id,
            sourceId: base.sourceId,
            kind: base.kind,
            confidence: base.confidence,
            sourceQuote: base.sourceQuote,
            title: existing.title,
            suggestedDate: existing.suggestedDate ?? base.suggestedDate,
            isAllDay: existing.isAllDay,
            location: existing.location ?? base.location,
            priorityLabel: existing.priorityLabel ?? base.priorityLabel,
            memoId: base.memoId,
            isEditing: existing.isEditing,
            isAdded: existing.isAdded,
            isDismissed: existing.isDismissed,
            isProcessing: existing.isProcessing
        )
    }

    @MainActor
    private func updateDetection(_ updated: ActionItemDetectionUI) {
        if let idx = detectionItems.firstIndex(where: { $0.id == updated.id }) {
            detectionItems[idx] = updated
        }
    }

    // Key used to persist "handled" detections.
    // Use the detection's own stable sourceId (UUID from detection payload) for uniqueness.
    private func detectionKey(for ui: ActionItemDetectionUI) -> String {
        return ui.sourceId
    }

    @MainActor
    private func handleSingleAdd(_ item: ActionItemDetectionUI) async {
        setProcessing(item.id, to: true)
        defer { setProcessing(item.id, to: false) }

        do {
            let identifier: String
            switch item.kind {
            case .event:
                identifier = try await addEvent(for: item)
                createdArtifacts[item.id] = CreatedArtifact(kind: .event, identifier: identifier)
            case .reminder:
                identifier = try await addReminder(for: item)
                createdArtifacts[item.id] = CreatedArtifact(kind: .reminder, identifier: identifier)
            }

            addedDetections.insert(item.id)
            if let idx = detectionItems.firstIndex(where: { $0.id == item.id }) {
                detectionItems[idx].isAdded = true
            }

            HapticManager.shared.playSuccess()
            appendAddedMessage(for: item)
        } catch {
            HapticManager.shared.playError()
        }
    }

    @MainActor
    private func handleUndo(id: UUID) async {
        guard let artifact = createdArtifacts[id] else {
            addedDetections.remove(id)
            createdArtifacts.removeValue(forKey: id)
            return
        }

        do {
            switch artifact.kind {
            case .event:
                try await container.eventKitRepository().deleteEvent(with: artifact.identifier)
            case .reminder:
                try await container.eventKitRepository().deleteReminder(with: artifact.identifier)
            }
            addedDetections.remove(id)
            createdArtifacts.removeValue(forKey: id)
            if let ui = detectionItems.first(where: { $0.id == id }) {
                let key = detectionKey(for: ui)
                addedRecords.removeAll { $0.id == key }
                if let memoId = ui.memoId ?? memoId {
                    handledStore.remove(key, for: memoId)
                }
            }
            HapticManager.shared.playSuccess()
        } catch {
            HapticManager.shared.playError()
        }
    }

    @MainActor
    private func setProcessing(_ id: UUID, to value: Bool) {
        if let idx = detectionItems.firstIndex(where: { $0.id == id }) {
            detectionItems[idx].isProcessing = value
        }
    }

    @MainActor
    private func addEvent(for item: ActionItemDetectionUI) async throws -> String {
        guard let base = eventSources[item.id] else {
            throw EventKitError.invalidEventData(field: "event source missing")
        }

        let event = buildEventPayload(from: item, base: base)
        try await ensureCalendarPermission()
        try await loadDestinationsIfNeeded(for: [item])

        let repo = container.eventKitRepository()
        let suggested = try await repo.suggestCalendar(for: event)
        let calendar = suggested ?? defaultCalendar ?? availableCalendars.first
        guard let calendar else {
            throw EventKitError.calendarNotFound(identifier: "default")
        }

        let useCase = container.createCalendarEventUseCase()
        return try await useCase.execute(event: event, calendar: calendar)
    }

    @MainActor
    private func addReminder(for item: ActionItemDetectionUI) async throws -> String {
        guard let base = reminderSources[item.id] else {
            throw EventKitError.invalidEventData(field: "reminder source missing")
        }

        let reminder = buildReminderPayload(from: item, base: base)
        try await ensureReminderPermission()
        try await loadDestinationsIfNeeded(for: [item])

        let repo = container.eventKitRepository()
        let suggested = try await repo.suggestReminderList(for: reminder)
        let list = suggested ?? defaultReminderList ?? availableReminderLists.first
        guard let list else {
            throw EventKitError.reminderListNotFound(identifier: "default")
        }

        let useCase = container.createReminderUseCase()
        return try await useCase.execute(reminder: reminder, list: list)
    }

    @MainActor
    private func handleBatchAdd(selected: [ActionItemDetectionUI], calendar: CalendarDTO?, reminderList: CalendarDTO?) async {
        guard !selected.isEmpty else { return }

        selected.forEach { updateDetection($0) }
        let ids = selected.map { $0.id }
        ids.forEach { setProcessing($0, to: true) }
        defer { ids.forEach { setProcessing($0, to: false) } }

        let eventItems = selected.filter { $0.kind == .event }
        let reminderItems = selected.filter { $0.kind == .reminder }

        do {
            var totalAdded = 0
            var failureMessages: [String] = []

            if !eventItems.isEmpty {
                try await ensureCalendarPermission()
                try await loadDestinationsIfNeeded(for: eventItems)
                let destination = calendar ?? defaultCalendar ?? availableCalendars.first
                guard let destination else { throw EventKitError.calendarNotFound(identifier: "default") }

                let tuples = try eventItems.map { item -> (ActionItemDetectionUI, EventsData.DetectedEvent) in
                    guard let base = eventSources[item.id] else {
                        throw EventKitError.invalidEventData(field: "event source missing")
                    }
                    return (item, buildEventPayload(from: item, base: base))
                }

                let result = try await batchAddEvents(tuples, calendar: destination)
                totalAdded += result.success
                failureMessages.append(contentsOf: result.failures)
            }

            if !reminderItems.isEmpty {
                try await ensureReminderPermission()
                try await loadDestinationsIfNeeded(for: reminderItems)
                let destination = reminderList ?? defaultReminderList ?? availableReminderLists.first
                guard let destination else { throw EventKitError.reminderListNotFound(identifier: "default") }

                let tuples = try reminderItems.map { item -> (ActionItemDetectionUI, RemindersData.DetectedReminder) in
                    guard let base = reminderSources[item.id] else {
                        throw EventKitError.invalidEventData(field: "reminder source missing")
                    }
                    return (item, buildReminderPayload(from: item, base: base))
                }

                let result = try await batchAddReminders(tuples, list: destination)
                totalAdded += result.success
                failureMessages.append(contentsOf: result.failures)
            }

            if failureMessages.isEmpty { HapticManager.shared.playSuccess() } else { HapticManager.shared.playWarning() }
        } catch {
            HapticManager.shared.playError()
        }
    }

    @MainActor
    private func batchAddEvents(_ items: [(ActionItemDetectionUI, EventsData.DetectedEvent)], calendar: CalendarDTO) async throws -> (success: Int, failures: [String]) {
        let useCase = container.createCalendarEventUseCase()
        let events = items.map { $0.1 }
        var mapping: [String: CalendarDTO] = [:]
        for event in events { mapping[event.id] = calendar }

        let results = try await useCase.execute(events: events, calendarMapping: mapping)
        var successCount = 0
        var failures: [String] = []

        for (ui, event) in items {
            switch results[event.id] {
            case .success(let createdId):
                successCount += 1
                createdArtifacts[ui.id] = CreatedArtifact(kind: .event, identifier: createdId)
                addedDetections.insert(ui.id)
                if let idx = detectionItems.firstIndex(where: { $0.id == ui.id }) {
                    detectionItems[idx].isAdded = true
                }
                appendAddedMessage(for: ui)
            case .failure(let error):
                failures.append(error.localizedDescription)
            case .none:
                failures.append("Failed to create \(ui.title)")
            }
        }

        return (successCount, failures)
    }

    @MainActor
    private func batchAddReminders(_ items: [(ActionItemDetectionUI, RemindersData.DetectedReminder)], list: CalendarDTO) async throws -> (success: Int, failures: [String]) {
        let useCase = container.createReminderUseCase()
        let reminders = items.map { $0.1 }
        var mapping: [String: CalendarDTO] = [:]
        for reminder in reminders { mapping[reminder.id] = list }

        let results = try await useCase.execute(reminders: reminders, listMapping: mapping)
        var successCount = 0
        var failures: [String] = []

        for (ui, reminder) in items {
            switch results[reminder.id] {
            case .success(let createdId):
                successCount += 1
                createdArtifacts[ui.id] = CreatedArtifact(kind: .reminder, identifier: createdId)
                addedDetections.insert(ui.id)
                if let idx = detectionItems.firstIndex(where: { $0.id == ui.id }) {
                    detectionItems[idx].isAdded = true
                }
                appendAddedMessage(for: ui)
            case .failure(let error):
                failures.append(error.localizedDescription)
            case .none:
                failures.append("Failed to create \(ui.title)")
            }
        }

        return (successCount, failures)
    }

    private func buildEventPayload(from item: ActionItemDetectionUI, base: EventsData.DetectedEvent) -> EventsData.DetectedEvent {
        let startDate = item.suggestedDate ?? base.startDate
        var endDate = base.endDate

        if let baseStart = base.startDate, let baseEnd = base.endDate, let startDate {
            let duration = baseEnd.timeIntervalSince(baseStart)
            if duration > 0 {
                endDate = startDate.addingTimeInterval(duration)
            }
        }

        return EventsData.DetectedEvent(
            id: base.id,
            title: item.title,
            startDate: startDate,
            endDate: endDate,
            location: item.location ?? base.location,
            participants: base.participants,
            confidence: base.confidence,
            sourceText: base.sourceText,
            memoId: base.memoId
        )
    }

    private func buildReminderPayload(from item: ActionItemDetectionUI, base: RemindersData.DetectedReminder) -> RemindersData.DetectedReminder {
        RemindersData.DetectedReminder(
            id: base.id,
            title: item.title,
            dueDate: item.suggestedDate ?? base.dueDate,
            priority: base.priority,
            confidence: base.confidence,
            sourceText: base.sourceText,
            memoId: base.memoId
        )
    }

    @MainActor
    private func loadDestinationsIfNeeded(for items: [ActionItemDetectionUI]) async throws {
        if items.contains(where: { $0.kind == .event }) && !calendarsLoaded {
            let repo = container.eventKitRepository()
            availableCalendars = try await repo.getCalendars()
            defaultCalendar = try await repo.getDefaultCalendar() ?? availableCalendars.first
            calendarsLoaded = true
        }

        if items.contains(where: { $0.kind == .reminder }) && !reminderListsLoaded {
            let repo = container.eventKitRepository()
            availableReminderLists = try await repo.getReminderLists()
            defaultReminderList = try await repo.getDefaultReminderList() ?? availableReminderLists.first
            reminderListsLoaded = true
        }
    }

    @MainActor
    private func ensureCalendarPermission() async throws {
        await permissionService.checkCalendarPermission(ignoreCache: true)
        if permissionService.calendarPermissionState.isAuthorized { return }
        if permissionService.calendarPermissionState.canRequest {
            _ = try await permissionService.requestCalendarAccess()
        }
        if !permissionService.calendarPermissionState.isAuthorized {
            throw EventKitError.permissionDenied(type: .calendar)
        }
    }

    @MainActor
    private func ensureReminderPermission() async throws {
        await permissionService.checkReminderPermission(ignoreCache: true)
        if permissionService.reminderPermissionState.isAuthorized { return }
        if permissionService.reminderPermissionState.canRequest {
            _ = try await permissionService.requestReminderAccess()
        }
        if !permissionService.reminderPermissionState.isAuthorized {
            throw EventKitError.permissionDenied(type: .reminder)
        }
    }

    @MainActor
    private func appendAddedMessage(for item: ActionItemDetectionUI) {
        let date: Date? = {
            if let d = item.suggestedDate { return d }
            switch item.kind {
            case .event: return eventSources[item.id]?.startDate
            case .reminder: return reminderSources[item.id]?.dueDate
            }
        }()
        let dateText = date.map { formatShortDate($0) }
        let prefix = item.kind == .event ? "Added event to calendar" : "Added reminder"
        let quotedTitle = "“\(item.title)”"
        let msg: String
        if let dateText {
            msg = "\(prefix) \(quotedTitle) for \(dateText)"
        } else {
            // For reminders without a date, omit the trailing date phrase
            msg = "\(prefix) \(quotedTitle)"
        }
        let key = detectionKey(for: item)
        addedRecords.removeAll { $0.id == key }
        addedRecords.append(AddedRecord(id: key, text: msg))
        if let memoId = item.memoId ?? memoId {
            handledStore.add(key, message: msg, for: memoId)
        }
    }

    private var shouldShowPermissionExplainer: Bool {
        // Show explainer if either permission not determined or denied/restricted
        let cal = permissionService.calendarPermissionState
        let rem = permissionService.reminderPermissionState
        return !(cal.isAuthorized && rem.isAuthorized)
    }

    private func eventLine(_ ev: EventsData.DetectedEvent) -> String {
        var parts: [String] = [ev.title]
        if let start = ev.startDate {
            parts.append("– " + formatShortDate(start))
        }
        if let loc = ev.location, !loc.isEmpty {
            parts.append("@ " + loc)
        }
        return parts.joined(separator: " ")
    }

    private func reminderLine(_ r: RemindersData.DetectedReminder) -> String {
        var parts: [String] = [r.title]
        if let due = r.dueDate {
            parts.append("– due " + formatShortDate(due))
        }
        parts.append("[" + r.priority.rawValue + "]")
        return parts.joined(separator: " ")
    }

    private func formatShortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    private func dedupeDetections(
        events: [EventsData.DetectedEvent],
        reminders: [RemindersData.DetectedReminder]
    ) -> ([EventsData.DetectedEvent], [RemindersData.DetectedReminder]) {
        var finalEvents: [EventsData.DetectedEvent] = []
        var finalReminders = reminders
        var reservedReminderKeys = Set<String>()

        func normalize(_ text: String) -> String {
            text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func reminderKey(for reminder: RemindersData.DetectedReminder) -> String {
            let source = reminder.sourceText.isEmpty ? reminder.title : reminder.sourceText
            return normalize(source)
        }

        func eventKey(for event: EventsData.DetectedEvent) -> String {
            let source = event.sourceText.isEmpty ? event.title : event.sourceText
            return normalize(source)
        }

        let meetingKeywords = [
            "meeting", "meet", "sync", "call", "review", "session",
            "standup", "retro", "1:1", "one-on-one", "interview", "doctor",
            "appointment", "consult", "therapy", "coaching"
        ]

        for event in events {
            let key = eventKey(for: event)
            let titleLower = event.title.lowercased()
            let hasKeyword = meetingKeywords.contains { titleLower.contains($0) }
            let hasParticipants = !(event.participants?.isEmpty ?? true)
            let hasLocation = !(event.location?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasStartDate = event.startDate != nil
            let qualifiesAsEvent = hasStartDate && (hasKeyword || hasParticipants || hasLocation)

            if qualifiesAsEvent {
                finalEvents.append(event)
                if !key.isEmpty { reservedReminderKeys.insert(key) }
            } else {
                // Treat as reminder-style task; ensure a reminder exists
                let alreadyHasReminder = finalReminders.contains { reminderKey(for: $0) == key && !key.isEmpty }
                if !alreadyHasReminder {
                    let converted = RemindersData.DetectedReminder(
                        id: event.id,
                        title: event.title,
                        dueDate: event.startDate,
                        priority: .medium,
                        confidence: event.confidence,
                        sourceText: event.sourceText,
                        memoId: event.memoId
                    )
                    finalReminders.append(converted)
                }
            }
        }

        if !reservedReminderKeys.isEmpty {
            finalReminders.removeAll { reminder in
                let key = reminderKey(for: reminder)
                return !key.isEmpty && reservedReminderKeys.contains(key)
            }
        }

        // Deduplicate reminders by key while preserving order
        var seenReminderKeys = Set<String>()
        finalReminders = finalReminders.filter { reminder in
            let key = reminderKey(for: reminder)
            if key.isEmpty { return true }
            if seenReminderKeys.contains(key) {
                return false
            }
            seenReminderKeys.insert(key)
            return true
        }

        return (finalEvents, finalReminders)
    }

    // MARK: - Placeholder Views

    @ViewBuilder
    private var summaryPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                Text("Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textSecondary))

                Spacer()

                LoadingIndicator(size: .small)
            }

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.semantic(.separator).opacity(0.3))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.semantic(.separator).opacity(0.3))
                    .frame(height: 12)
                    .scaleEffect(x: 0.75, anchor: .leading)
            }
        }
        .redacted(reason: .placeholder)
        .frame(minHeight: 130)
    }

    @ViewBuilder
    private var reflectionQuestionsPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                Text("Reflection Questions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.semantic(.textSecondary))

                Spacer()

                LoadingIndicator(size: .small)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.semantic(.textSecondary))
                            .frame(minWidth: 20)

                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.semantic(.separator).opacity(0.3))
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.semantic(.separator).opacity(0.3))
                                .frame(height: 12)
                                .scaleEffect(x: 0.6, anchor: .leading)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(Color.semantic(.separator).opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .redacted(reason: .placeholder)
        .frame(minHeight: 180)
    }

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
