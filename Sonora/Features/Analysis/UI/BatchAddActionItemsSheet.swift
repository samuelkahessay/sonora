import SwiftUI

struct BatchAddActionItemsSheet: View {
    @Binding var items: [ActionItemDetectionUI]
    @Binding var include: Set<UUID>
    let isPro: Bool
    let onEdit: (UUID) -> Void
    let onAddSelected: ([ActionItemDetectionUI]) -> Void
    let onDismiss: () -> Void

    private var selectedCount: Int { items.filter { include.contains($0.id) }.count }

    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { include.contains(item.id) },
                            set: { newVal in
                                if newVal { include.insert(item.id) } else { include.remove(item.id) }
                            }
                        ))
                        .labelsHidden()

                        VStack(alignment: .leading, spacing: 6) {
                            // Removed type and confidence badges for a cleaner UI
                            Text(item.title)
                                .font(.body.weight(.semibold))
                            if let d = item.suggestedDate {
                                Text(DateFormatter.ai_short.string(from: d))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 8) {
                                Button("Edit") { onEdit(item.id) }.buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Review & Add All (\(items.count))")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Selected (\(selectedCount))") {
                        let selected = items.filter { include.contains($0.id) }
                        onAddSelected(selected)
                    }
                    .disabled(selectedCount == 0)
                }
            }
        }
    }
}
