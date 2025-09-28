import SwiftUI

struct ActionItemDetectionCard: View {
    @State var model: ActionItemDetectionUI
    let isPro: Bool
    let onAdd: (ActionItemDetectionUI) -> Void
    let onEditToggle: (UUID) -> Void
    let onDismiss: (UUID) -> Void
    let onQuickChip: (UUID, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // header removed (confidence badges)
            quoteChip
            // type badge removed (Calendar/Reminder)
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
        // Dismiss control moved to top-right "X"
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
    }

    @ViewBuilder private var quoteChip: some View {
        if !model.sourceQuote.isEmpty {
            Text("\"\(model.sourceQuote)\"")
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
                .padding(.horizontal, 12).padding(.vertical, 8)
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
                    // Gating placeholder — will be wired to paywall later
                    onAdd(model)
                }
            }) {
                Text(model.kind == .reminder ? "Add to Reminders" : "Add to Calendar")
                    .font(.callout.weight(.semibold))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("Edit") { onEditToggle(model.id) }
                .buttonStyle(.bordered)
        }
        .padding(.top, 2)
    }

    @ViewBuilder private var editorIfNeeded: some View {
        if model.isEditing {
            VStack(alignment: .leading, spacing: 8) {
                if model.kind == .reminder {
                    // Minimal fields; full wiring later
                    TextField("Title", text: Binding(
                        get: { model.title },
                        set: { model.title = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                } else {
                    TextField("Title", text: Binding(
                        get: { model.title },
                        set: { model.title = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Button("Save & Add") { onAdd(model) }
                        .buttonStyle(.borderedProminent)
                    Button("Cancel") { onEditToggle(model.id) }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.top, 8)
        }
    }

    // confidence badges removed from UI (kept in backend)
}
