import SwiftUI
import EventKit

struct ReminderConfirmationView: View {
    let detectedReminders: [RemindersData.DetectedReminder]
    init(detectedReminders: [RemindersData.DetectedReminder]) { self.detectedReminders = detectedReminders }

    @SwiftUI.Environment(\.diContainer) private var container: DIContainer
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    @State private var lists: [EKCalendar] = []
    @State private var selectedList: EKCalendar? = nil
    @State private var selectedIds: Set<String> = []
    @State private var editable: [String: EditableReminder] = [:]
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var editingId: String? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                CalendarSelectionView(selectedCalendar: $selectedList, calendars: lists)

                List {
                    ForEach(detectedReminders, id: \.id) { r in
                        HStack(alignment: .top, spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { selectedIds.contains(r.id) },
                                set: { v in if v { selectedIds.insert(r.id) } else { selectedIds.remove(r.id) } }
                            ))
                            .labelsHidden()

                            VStack(alignment: .leading, spacing: 4) {
                                Text(editable[r.id]?.title ?? r.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let date = editable[r.id]?.dueDate ?? r.dueDate {
                                    Text(formatDate(date))
                                        .font(.caption)
                                        .foregroundColor(.semantic(.textSecondary))
                                }
                                Text("Priority: \((editable[r.id]?.priority ?? r.priority).rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.semantic(.textSecondary))
                            }
                            Spacer()
                            Button("Edit") { editingId = r.id }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                .listStyle(.insetGrouped)

                Button(action: addSelectedReminders) {
                    HStack {
                        if isLoading { ProgressView().progressViewStyle(.circular) }
                        Text("Add Selected Reminders")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || selectedIds.isEmpty || selectedList == nil)
                .padding(.horizontal)
            }
            .navigationTitle("Add to Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .onAppear { Task { await loadData() } }
        .sheet(isPresented: Binding<Bool>(get: { editingId != nil }, set: { if !$0 { editingId = nil } })) {
            if let id = editingId, let binding = bindingForEditable(id: id) {
                ReminderEditView(reminder: binding)
            } else { EmptyView() }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "Unknown error") }
    }

    private func loadData() async {
        // Editable copies & defaults: preselect high confidence
        var m: [String: EditableReminder] = [:]
        var defaults: Set<String> = []
        for r in detectedReminders {
            m[r.id] = EditableReminder(from: r)
            if r.confidence >= 0.8 { defaults.insert(r.id) }
        }
        editable = m
        selectedIds = defaults.isEmpty ? Set(detectedReminders.map { $0.id }) : defaults

        do {
            _ = try await container.eventKitPermissionService().requestReminderAccess()
            let fetched = try await container.eventKitRepository().getReminderLists()
            lists = fetched
            if selectedList == nil {
                selectedList = try await container.eventKitRepository().getDefaultReminderList() ?? fetched.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addSelectedReminders() {
        guard let list = selectedList else { return }
        isLoading = true
        Task {
            do {
                let selected = detectedReminders.compactMap { o -> RemindersData.DetectedReminder? in
                    guard selectedIds.contains(o.id), let e = editable[o.id] else { return nil }
                    return e.toDetectedReminder()
                }
                var mapping: [String: EKCalendar] = [:]
                for r in selected { mapping[r.id] = list }
                let results = try await container.createReminderUseCase().execute(reminders: selected, listMapping: mapping)
                let failures = results.values.filter { if case .failure = $0 { true } else { false } }
                if failures.isEmpty { HapticManager.shared.playSuccess(); dismiss() }
                else { HapticManager.shared.playWarning(); errorMessage = "Some reminders could not be created (\(failures.count))." }
            } catch {
                HapticManager.shared.playError(); errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func bindingForEditable(id: String) -> Binding<EditableReminder>? {
        guard editable[id] != nil else { return nil }
        return Binding(get: { editable[id]! }, set: { editable[id] = $0 })
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: date)
    }
}

struct ReminderEditView: View {
    @Binding var reminder: EditableReminder
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Title", text: $reminder.title)
                }
                Section(header: Text("Due Date")) {
                    DatePicker("Due", selection: Binding(get: { reminder.dueDate ?? Date() }, set: { reminder.dueDate = $0 }), displayedComponents: [.date, .hourAndMinute])
                }
                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $reminder.priority) {
                        ForEach(RemindersData.DetectedReminder.Priority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                }
            }
            .navigationTitle("Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct EditableReminder: Identifiable, Equatable {
    var id: String
    var title: String
    var dueDate: Date?
    var priority: RemindersData.DetectedReminder.Priority
    var confidence: Float
    var sourceText: String
    var memoId: UUID?

    init(from r: RemindersData.DetectedReminder) {
        id = r.id; title = r.title; dueDate = r.dueDate; priority = r.priority; confidence = r.confidence; sourceText = r.sourceText; memoId = r.memoId
    }

    func toDetectedReminder() -> RemindersData.DetectedReminder {
        RemindersData.DetectedReminder(
            id: id,
            title: title,
            dueDate: dueDate,
            priority: priority,
            confidence: confidence,
            sourceText: sourceText,
            memoId: memoId
        )
    }
}
