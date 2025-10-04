import SwiftUI

/// Displays a simple to-do item from Lite Distill analysis (free tier)
/// Read-only view without EventKit integration - just shows extracted tasks
internal struct SimpleTodoRowView: View {
    let todo: SimpleTodo

    @ScaledMetric private var spacing: CGFloat = 10
    @ScaledMetric private var iconSize: CGFloat = 16

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            // Priority indicator
            Image(systemName: todo.priority.iconName)
                .font(.system(size: iconSize))
                .foregroundColor(colorForPriority(todo.priority))
                .accessibilityHidden(true)
                .padding(.top, 2)

            // Todo text
            Text(todo.text)
                .font(SonoraDesignSystem.Typography.cardBody)
                .foregroundColor(.semantic(.textPrimary))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(todo.priority.rawValue) priority: \(todo.text)")
    }

    // MARK: - Helpers

    private func colorForPriority(_ priority: SimpleTodo.Priority) -> Color {
        switch priority.color {
        case "red":
            return .red
        case "orange":
            return .orange
        case "green":
            return .green
        default:
            return .semantic(.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview("Todo Rows") {
    VStack(alignment: .leading, spacing: 12) {
        SimpleTodoRowView(
            todo: SimpleTodo(text: "Email team about project boundaries", priority: .high)
        )

        SimpleTodoRowView(
            todo: SimpleTodo(text: "Schedule coffee meeting with Sarah", priority: .medium)
        )

        SimpleTodoRowView(
            todo: SimpleTodo(text: "Review notes from last week's reflection", priority: .low)
        )
    }
    .padding()
    .background(Color.semantic(.bgPrimary))
}
