import SwiftUI

internal struct ActionItemsHostSectionView: View {
    @ObservedObject var permissionService: EventKitPermissionService

    // Visible items after filtering/sorting (provided by parent state)
    let visibleItems: [ActionItemDetectionUI]

    let addedRecords: [DistillAddedRecord]
    let isPro: Bool
    let isDetectionPending: Bool

    @Binding var showBatchSheet: Bool
    @Binding var batchInclude: Set<UUID>

    let calendars: [CalendarDTO]
    let reminderLists: [CalendarDTO]
    let defaultCalendar: CalendarDTO?
    let defaultReminderList: CalendarDTO?

    let onOpenBatch: (Set<UUID>) -> Void
    let onEditToggle: (UUID) -> Void
    let onAdd: (ActionItemDetectionUI) -> Void
    let onDismissItem: (UUID) -> Void
    let onAddSelected: ([ActionItemDetectionUI], CalendarDTO?, CalendarDTO?) -> Void
    let onDismissSheet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if shouldShowPermissionExplainer {
                PermissionExplainerCard(
                    permissions: permissionService
                ) { DIContainer.shared.systemNavigator().openSettings(completion: nil) }
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

            if !visibleItems.isEmpty {
                VStack(spacing: 12) {
                    ForEach(visibleItems) { m in
                        ActionItemDetectionCard(
                            model: m,
                            isPro: isPro,
                            onAdd: { updated in onAdd(updated) },
                            onEditToggle: { id in onEditToggle(id) },
                            onDismiss: { id in onDismissItem(id) }
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
        .sheet(isPresented: $showBatchSheet) {
            BatchAddActionItemsSheet(
                items: .constant(visibleItems),
                include: $batchInclude,
                isPro: isPro,
                calendars: calendars,
                reminderLists: reminderLists,
                defaultCalendar: defaultCalendar,
                defaultReminderList: defaultReminderList,
                onEdit: { id in onEditToggle(id) },
                onAddSelected: { selected, calendar, reminderList in
                    showBatchSheet = false
                    onAddSelected(selected, calendar, reminderList)
                },
                onDismiss: { showBatchSheet = false; onDismissSheet() }
            )
        }
    }

    private var shouldShowPermissionExplainer: Bool {
        let cal = permissionService.calendarPermissionState
        let rem = permissionService.reminderPermissionState
        return !(cal.isAuthorized && rem.isAuthorized)
    }

    private var reviewCount: Int { visibleItems.count }

    private func openBatchReview() {
        let selected = Set(visibleItems.map { $0.id })
        batchInclude = selected
        onOpenBatch(selected)
    }
}
