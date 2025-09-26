import SwiftUI

/// Delete All Data button without a card background; sits at bottom of Settings.
struct DangerZoneSectionView: View {
    @StateObject private var controller = PrivacyController()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button(role: .destructive, action: { controller.requestDeleteAll() }) {
                Label("Delete All Data", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(.semantic(.error))
            .disabled(controller.isDeleting)
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
    }
}

#Preview {
    DangerZoneSectionView().padding()
}
