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
    // Pro gating (Action Items: detection visible to all; adds gated later)
    private var isPro: Bool { DIContainer.shared.storeKitService().isPro }
    @State private var showPaywall: Bool = false
    
    // Convenience initializers for backward compatibility
    init(data: DistillData, envelope: AnalyzeEnvelope<DistillData>) {
        self.data = data
        self.envelope = envelope
        self.partialData = nil
        self.progress = nil
    }
    
    init(partialData: PartialDistillData, progress: DistillProgressUpdate) {
        self.data = partialData.toDistillData()
        self.envelope = nil
        self.partialData = partialData
        self.progress = progress
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
    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var toastUndoId: UUID? = nil
    @StateObject private var permissionService = DIContainer.shared.eventKitPermissionService() as! EventKitPermissionService
    
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
                Image(systemName: "bolt.fill").foregroundColor(.semantic(.warning))
                Text("Action Items")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if reviewCount > 0 {
                    Button("Review & Add All (\(reviewCount))") { openBatchReview() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }

            // Detection Cards (visible to all; adds gated by Pro later)
            if !detectionItemsFiltered.isEmpty {
                VStack(spacing: 12) {
                    ForEach(detectionItemsFiltered) { m in
                        ActionItemDetectionCard(
                            model: m,
                            isPro: isPro,
                            onAdd: { _ in onAddSingle(m.id) },
                            onEditToggle: { id in toggleEdit(id) },
                            onDismiss: { id in dismiss(id) },
                            onQuickChip: { id, chip in applyChip(id, chip: chip) }
                        )
                    }
                }
            } else {
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
                onEdit: { id in toggleEdit(id) },
                onAddSelected: { _ in showBatchSheet = false },
                onDismiss: { showBatchSheet = false }
            )
        }
        .overlay(alignment: .bottom) {
            if showToast {
                HStack {
                    Text(toastText)
                        .font(.callout)
                    Spacer()
                    if let id = toastUndoId {
                        Button("Undo") { undoAdd(id) }
                            .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color.semantic(.fillSecondary))
                .cornerRadius(12)
                .shadow(radius: 8)
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
        batchInclude = Set(detectionItemsFiltered.map { $0.id }) // default include all
        showBatchSheet = true
    }
    private func prepareDetectionsIfNeeded() {
        let events = eventsForUI
        let reminders = remindersForUI
        var arr: [ActionItemDetectionUI] = []
        arr.append(contentsOf: events.map { ActionItemDetectionUI.fromEvent($0) })
        arr.append(contentsOf: reminders.map { ActionItemDetectionUI.fromReminder($0) })
        detectionItems = arr
    }
    private func toggleEdit(_ id: UUID) {
        if let idx = detectionItems.firstIndex(where: { $0.id == id }) {
            detectionItems[idx].isEditing.toggle()
        }
    }
    private func dismiss(_ id: UUID) { dismissedDetections.insert(id) }
    private func onAddSingle(_ id: UUID) {
        addedDetections.insert(id)
        if let m = detectionItems.first(where: { $0.id == id }) {
            toastText = m.kind == .reminder ? "Added to Reminders" : "Added to Calendar"
            toastUndoId = id
            withAnimation { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation { showToast = false }
                toastUndoId = nil
            }
        }
    }
    private func undoAdd(_ id: UUID) {
        addedDetections.remove(id)
        withAnimation { showToast = false }
        toastUndoId = nil
    }
    private func applyChip(_ id: UUID, chip: String) {
        // Stub mapping for chips – will be wired later
        if let idx = detectionItems.firstIndex(where: { $0.id == id }) {
            var d = detectionItems[idx]
            // Simple demo: set date to now with small offsets
            switch chip.lowercased() {
            case "today", "today evening": d.suggestedDate = Date().addingTimeInterval(60*60*3)
            case "tomorrow": d.suggestedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
            case "this weekend": d.suggestedDate = nextSaturday(atHour: 10)
            case "all day": d.isAllDay.toggle()
            default: break
            }
            detectionItems[idx] = d
        }
    }
    private func nextSaturday(atHour hour: Int) -> Date? {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let now = Date()
        for i in 0..<14 {
            if let d = cal.date(byAdding: .day, value: i, to: now) {
                if cal.component(.weekday, from: d) == 7 { // Saturday
                    return cal.date(bySettingHour: hour, minute: 0, second: 0, of: d)
                }
            }
        }
        return nil
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
        } else {
            parts.append("Events & Reminders:\nNo events or reminders detected")
        }
        return parts.joined(separator: "\n\n")
    }

}
