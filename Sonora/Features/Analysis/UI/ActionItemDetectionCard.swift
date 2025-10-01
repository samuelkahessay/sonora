import SwiftUI

struct ActionItemDetectionCard: View {
    let inputModel: ActionItemDetectionUI
    @State private var model: ActionItemDetectionUI
    let isPro: Bool
    let onEvent: (ActionItemEvent) -> Void

    @ScaledMetric private var cardContentSpacing: CGFloat = 10
    @ScaledMetric private var titleSubtitleSpacing: CGFloat = 4
    @ScaledMetric private var buttonSpacing: CGFloat = 12
    @ScaledMetric private var editorSpacing: CGFloat = 10
    @ScaledMetric private var controlSpacing: CGFloat = 6

    init(
        model: ActionItemDetectionUI,
        isPro: Bool,
        onEvent: @escaping (ActionItemEvent) -> Void
    ) {
        self.inputModel = model
        self._model = State(initialValue: model)
        self.isPro = isPro
        self.onEvent = onEvent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: cardContentSpacing) {
            quoteChip
            titleSubtitle
            buttonsRow
            editorIfNeeded
        }
        .padding(SonoraDesignSystem.Spacing.cardPadding)
        .background(Color.semantic(.fillSecondary))
        .cornerRadius(SonoraDesignSystem.Spacing.md_sm)
        .overlay(
            RoundedRectangle(cornerRadius: SonoraDesignSystem.Spacing.md_sm)
                .stroke(model.isEditing ? Color.semantic(.brandPrimary) : Color.clear, lineWidth: 1.5)
        )
        .overlay(alignment: .topTrailing) {
            Button(action: { onEvent(.dismiss(id: model.id)) }) {
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
                .font(SonoraDesignSystem.Typography.metadata)
                .foregroundColor(.semantic(.textSecondary))
                .padding(.horizontal, SonoraDesignSystem.Spacing.md_sm)
                .padding(.vertical, SonoraDesignSystem.Spacing.sm)
                .background(Color.semantic(.bgSecondary))
                .cornerRadius(SonoraDesignSystem.Spacing.sm)
        }
    }

    @ViewBuilder private var titleSubtitle: some View {
        VStack(alignment: .leading, spacing: titleSubtitleSpacing) {
            Text(model.title)
                .font(SonoraDesignSystem.Typography.cardTitle)
                .foregroundColor(.semantic(.textPrimary))
            if let d = model.suggestedDate {
                Text("Suggested \(DateFormatter.ai_short.string(from: d))\(model.isAllDay ? " • All day" : "")")
                    .font(SonoraDesignSystem.Typography.metadata)
                    .foregroundColor(.semantic(.textSecondary))
            } else {
                Text("No specific date mentioned")
                    .font(SonoraDesignSystem.Typography.metadata)
                    .foregroundColor(.semantic(.textSecondary))
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var buttonsRow: some View {
        HStack(spacing: buttonSpacing) {
            if !model.isEditing {
                primaryAddButton
            }

            Button(action: { onEvent(.editToggle(id: model.id)) }) {
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
            VStack(alignment: .leading, spacing: editorSpacing) {
                Picker("Type", selection: Binding(
                    get: { model.kind },
                    set: { model.kind = $0 }
                )) {
                    Text("Event").tag(ActionItemDetectionKind.event)
                    Text("Reminder").tag(ActionItemDetectionKind.reminder)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Item type")

                TextField("Title", text: Binding(
                    get: { model.title },
                    set: { model.title = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Item title")

                if model.kind == .event {
                    EventDateControl(
                        date: $model.suggestedDate,
                        isAllDay: $model.isAllDay
                    )
                } else {
                    ReminderDateControl(
                        date: $model.suggestedDate,
                        isAllDay: $model.isAllDay
                    )
                }

                primaryAddButton
                    .disabled(model.isProcessing || (model.kind == .event && model.suggestedDate == nil))
                    .padding(.top, 4)
            }
            .padding(.top, 8)
        }
    }

    private var addButtonTitle: String {
        model.kind == .reminder ? "Add to Reminders" : "Add to Calendar"
    }

    @ViewBuilder private var primaryAddButton: some View {
        Button(action: {
            onEvent(.add(item: model))
        }, label: {
            if model.isProcessing {
                HStack(spacing: itemSpacing) {
                    ProgressView()
                    Text("Adding…")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(addButtonTitle)
                    .font(.callout.weight(.semibold))
                    .padding(.vertical, cardContentSpacing)
                    .frame(maxWidth: .infinity)
            }
        })
        .buttonStyle(.borderedProminent)
        .disabled(model.isProcessing || (model.kind == .event && model.suggestedDate == nil))
        .accessibilityLabel(addButtonTitle)
        .accessibilityHint(model.kind == .event ? "Adds event to calendar" : "Adds reminder to reminders list")
    }

    private var itemSpacing: CGFloat { 8 }
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
