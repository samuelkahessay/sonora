import SwiftUI

struct ActionItemDetectionCard: View {
    let inputModel: ActionItemDetectionUI
    @State private var model: ActionItemDetectionUI
    let isPro: Bool
    let onAdd: (ActionItemDetectionUI) -> Void
    let onEditToggle: (UUID) -> Void
    let onDismiss: (UUID) -> Void
    let onQuickChip: (UUID, String) -> Void

    init(
        model: ActionItemDetectionUI,
        isPro: Bool,
        onAdd: @escaping (ActionItemDetectionUI) -> Void,
        onEditToggle: @escaping (UUID) -> Void,
        onDismiss: @escaping (UUID) -> Void,
        onQuickChip: @escaping (UUID, String) -> Void
    ) {
        self.inputModel = model
        self._model = State(initialValue: model)
        self.isPro = isPro
        self.onAdd = onAdd
        self.onEditToggle = onEditToggle
        self.onDismiss = onDismiss
        self.onQuickChip = onQuickChip
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            quoteChip
            titleSubtitle
            chipsRow
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

    @ViewBuilder private var chipsRow: some View {
        if model.canQuickChip {
            HStack(spacing: 8) {
                if model.kind == .reminder {
                    chip("Today evening")
                    chip("Tomorrow")
                    chip("This weekend")
                } else {
                    chip("Today")
                    chip("Tomorrow")
                    chip("All day")
                }
                Spacer()
            }
            .padding(.top, 2)
        }
    }

    private func chip(_ text: String) -> some View {
        Button(action: {
            onQuickChip(model.id, text)
        }) {
            Text(text)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.semantic(.fillPrimary))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var buttonsRow: some View {
        HStack(spacing: 12) {
            Button(action: {
                if isPro {
                    onAdd(model)
                } else {
                    onAdd(model)
                }
            }) {
                if model.isProcessing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Adding…")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text(model.kind == .reminder ? "Add to Reminders" : "Add to Calendar")
                        .font(.callout.weight(.semibold))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isProcessing)

            Button("Edit") { onEditToggle(model.id) }
                .buttonStyle(.bordered)
                .disabled(model.isProcessing)
        }
        .padding(.top, 2)
    }

    @ViewBuilder private var editorIfNeeded: some View {
        if model.isEditing {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Title", text: Binding(
                    get: { model.title },
                    set: { model.title = $0 }
                ))
                .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save & Add") { onAdd(model) }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isProcessing)
                    Button("Cancel") { onEditToggle(model.id) }
                        .buttonStyle(.bordered)
                        .disabled(model.isProcessing)
                }
            }
            .padding(.top, 8)
        }
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
