import SwiftUI

struct ActionItemDetectionCard: View {
    let inputModel: ActionItemDetectionUI
    @State private var model: ActionItemDetectionUI
    let isPro: Bool
    let onAdd: (ActionItemDetectionUI) -> Void
    let onEditToggle: (UUID) -> Void
    let onDismiss: (UUID) -> Void

    init(
        model: ActionItemDetectionUI,
        isPro: Bool,
        onAdd: @escaping (ActionItemDetectionUI) -> Void,
        onEditToggle: @escaping (UUID) -> Void,
        onDismiss: @escaping (UUID) -> Void
    ) {
        self.inputModel = model
        self._model = State(initialValue: model)
        self.isPro = isPro
        self.onAdd = onAdd
        self.onEditToggle = onEditToggle
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            quoteChip
            titleSubtitle
            buttonsRow
            editorIfNeeded
        }
        .padding(14)
        .background(Color.semantic(.fillSecondary))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(model.isEditing ? Color.semantic(.brandPrimary) : Color.clear, lineWidth: 1.5)
        )
        .overlay(alignment: .topTrailing) {
            Button(action: { onDismiss(model.id) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.semantic(.textTertiary))
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss this item")
            .padding(8)
        }
        .syncState(with: inputModel) { model = $0 }
    }

    @ViewBuilder private var quoteChip: some View {
        if !model.sourceQuote.isEmpty {
            Text("\"\(model.sourceQuote)\"")
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.semantic(.bgSecondary))
                .cornerRadius(10)
        }
    }

    @ViewBuilder private var titleSubtitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.title)
                .font(.system(.headline, design: .serif))
                .fontWeight(.semibold)
                .foregroundColor(.semantic(.textPrimary))
            if let d = model.suggestedDate {
                Text("Suggested \(DateFormatter.ai_short.string(from: d))\(model.isAllDay ? " • All day" : "")")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            } else {
                Text("No specific date mentioned")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            }
        }
    }

    @ViewBuilder private var buttonsRow: some View {
        HStack(spacing: 12) {
            if !model.isEditing {
                primaryAddButton
            }

            Button(action: { onEditToggle(model.id) }) {
                Image(systemName: model.isEditing ? "xmark.circle" : "pencil")
            }
            .buttonStyle(.bordered)
            .disabled(model.isProcessing)
            .accessibilityLabel(model.isEditing ? "Cancel editing" : "Edit details")
        }
        .padding(.top, 2)
    }

    @ViewBuilder private var editorIfNeeded: some View {
        if model.isEditing {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Type", selection: Binding(
                    get: { model.kind },
                    set: { newKind in model.kind = newKind }
                )) {
                    Text("Event").tag(ActionItemDetectionKind.event)
                    Text("Reminder").tag(ActionItemDetectionKind.reminder)
                }
                .pickerStyle(.segmented)

                TextField("Title", text: Binding(
                    get: { model.title },
                    set: { model.title = $0 }
                ))
                .textFieldStyle(.roundedBorder)

                if model.kind == .event {
                    eventDateControls
                } else {
                    reminderDateControls
                }

                primaryAddButton
                    .disabled(model.isProcessing || (model.kind == .event && model.suggestedDate == nil))
                    .padding(.top, 4)
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder private var eventDateControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker(
                "Event Date",
                selection: Binding(
                    get: { model.suggestedDate ?? Date() },
                    set: { model.suggestedDate = $0 }
                ),
                displayedComponents: model.isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)

            Toggle("All-day", isOn: Binding(
                get: { model.isAllDay },
                set: { model.isAllDay = $0 }
            ))
        }
        .onAppear {
            if model.suggestedDate == nil {
                model.suggestedDate = Date()
            }
        }
    }

    @ViewBuilder private var reminderDateControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Include date", isOn: Binding(
                get: { model.suggestedDate != nil },
                set: { include in
                    if include {
                        if model.suggestedDate == nil { model.suggestedDate = Date() }
                    } else {
                        model.suggestedDate = nil
                        model.isAllDay = false
                    }
                }
            ))

            if model.suggestedDate != nil {
                DatePicker(
                    "Reminder Date",
                    selection: Binding(
                        get: { model.suggestedDate ?? Date() },
                        set: { model.suggestedDate = $0 }
                    ),
                    displayedComponents: model.isAllDay ? [.date] : [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)

                Toggle("All-day", isOn: Binding(
                    get: { model.isAllDay },
                    set: { model.isAllDay = $0 }
                ))
            }
        }
    }

    private var addButtonTitle: String {
        model.kind == .reminder ? "Add to Reminders" : "Add to Calendar"
    }

    @ViewBuilder private var primaryAddButton: some View {
        Button(action: {
            onAdd(model)
        }, label: {
            if model.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Adding…")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(addButtonTitle)
                    .font(.callout.weight(.semibold))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
        })
        .buttonStyle(.borderedProminent)
        .disabled(model.isProcessing || (model.kind == .event && model.suggestedDate == nil))
    }
}

private struct OnChangeSyncModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let action: (Value) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            content.onChange(of: value) { newValue in
                action(newValue)
            }
        }
    }
}

private extension View {
    func syncState<Value: Equatable>(with value: Value, action: @escaping (Value) -> Void) -> some View {
        modifier(OnChangeSyncModifier(value: value, action: action))
    }
}
