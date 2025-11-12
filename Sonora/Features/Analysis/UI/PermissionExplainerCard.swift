import SwiftUI

struct PermissionExplainerCard: View {
    @ObservedObject var permissions: EventKitPermissionService
    let onOpenSettings: () -> Void

    @State private var isRequesting = false
    @State private var showSettingsCTA = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundColor(.accentColor)
                Text("Add items to your Calendar and Reminders")
                    .font(.subheadline.weight(.semibold))
            }
            Text("Sonora can add action items so you can follow through.")
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))

            HStack(spacing: 10) {
                Button(action: requestAccess) {
                    if isRequesting {
                        ProgressView().progressViewStyle(.circular)
                    } else {
                        Text("Enable")
                            .font(.callout.weight(.semibold))
                    }
                }
                .buttonStyle(.borderedProminent)

                if showSettingsCTA {
                    Button("Open Settings", action: onOpenSettings)
                        .buttonStyle(.bordered)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                labelRow(
                    icon: permissions.calendarPermissionState.systemIconName,
                    text: "Calendar: \(permissions.calendarPermissionState.displayText)"
                )
                labelRow(
                    icon: permissions.reminderPermissionState.systemIconName,
                    text: "Reminders: \(permissions.reminderPermissionState.displayText)"
                )
            }
            .font(.caption)
            .foregroundColor(.semantic(.textSecondary))
        }
        .padding(14)
        .background(Color.semantic(.fillSecondary))
        .cornerRadius(12)
    }

    private func labelRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
    }

    private func requestAccess() {
        Task { @MainActor in
            isRequesting = true
            defer { isRequesting = false }
            do {
                _ = try await permissions.requestReminderAccess()
                _ = try await permissions.requestCalendarAccess()
                showSettingsCTA = false
            } catch {
                showSettingsCTA = true
            }
        }
    }
}
