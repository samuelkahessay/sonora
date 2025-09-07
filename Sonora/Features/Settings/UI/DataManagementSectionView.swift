import SwiftUI

struct DataManagementSectionView: View {
    @StateObject private var controller = PrivacyController()

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Data Management", systemImage: "internaldrive")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityAddTraits(.isHeader)

                // Export options group
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Export Options")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.semantic(.textPrimary))

                    ExportOptionButton(
                        icon: "doc.text",
                        title: "Export Transcripts",
                        subtitle: "Text files of all recordings"
                    ) {
                        controller.exportMemos = false
                        controller.exportTranscripts = true
                        controller.exportAnalysis = false
                        Task { await controller.exportData() }
                    }

                    ExportOptionButton(
                        icon: "sparkles",
                        title: "Export Analysis",
                        subtitle: "AI summaries and insights"
                    ) {
                        controller.exportMemos = false
                        controller.exportTranscripts = false
                        controller.exportAnalysis = true
                        Task { await controller.exportData() }
                    }

                    ExportOptionButton(
                        icon: "archivebox",
                        title: "Export Everything",
                        subtitle: "Complete backup with audio"
                    ) {
                        controller.exportMemos = true
                        controller.exportTranscripts = true
                        controller.exportAnalysis = true
                        Task { await controller.exportData() }
                    }
                }

                Divider().background(Color.semantic(.separator))

                // Delete all data
                Button(role: .destructive, action: { controller.requestDeleteAll() }) {
                    Label("Delete All Data", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(.semantic(.error))
                .disabled(controller.isDeleting)
            }
        }
        .alert(item: $controller.alertItem) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog(
            "Delete All Data?",
            isPresented: $controller.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                Task { await controller.deleteAllNow() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action permanently deletes all memos, transcripts, and analysis. This cannot be undone.")
        }
        .sheet(isPresented: $controller.isPresentingShareSheet, onDismiss: {
            controller.exportURL = nil
        }) {
            if let url = controller.exportURL {
                ActivityView(activityItems: [url])
                    .ignoresSafeArea()
            } else {
                Text("No export available")
            }
        }
    }
}

private struct ExportOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.semantic(.brandPrimary))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.semantic(.textPrimary))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textTertiary))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }
}

