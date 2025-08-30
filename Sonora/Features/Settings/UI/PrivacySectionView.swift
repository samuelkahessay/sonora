import SwiftUI

struct PrivacySectionView: View {
    @StateObject private var controller = PrivacyController()

    private let privacyURL = URL(string: "https://sonora.app/privacy")!
    private let termsURL = URL(string: "https://sonora.app/terms")!

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Privacy & Data")
                .font(.headline)

            // Links
            HStack(spacing: Spacing.lg) {
                Link(destination: privacyURL) {
                    label(icon: "hand.raised.fill", title: "Privacy Policy")
                }
                Link(destination: termsURL) {
                    label(icon: "doc.text.fill", title: "Terms of Use")
                }
            }

            // Actions
            VStack(spacing: Spacing.md) {
                Button(action: { Task { await controller.exportData() } }) {
                    HStack(spacing: Spacing.md) {
                        if controller.isExporting { ProgressView().scaleEffect(0.9) }
                        Image(systemName: "square.and.arrow.up")
                            .imageScale(.medium)
                        Text(controller.isExporting ? "Exporting…" : "Export Data")
                            .font(.body)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, Spacing.md)
                    .background(Color.semantic(.bgSecondary))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.semantic(.separator).opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(controller.isExporting || controller.isDeleting || controller.deleteScheduled || !controller.hasDataToExport)
                .opacity((controller.hasDataToExport && !controller.isExporting) ? 1.0 : 0.7)

                Button(role: .destructive, action: { controller.requestDeleteAll() }) {
                    HStack(spacing: Spacing.md) {
                        if controller.isDeleting { ProgressView().scaleEffect(0.9) }
                        Image(systemName: "trash.fill")
                            .imageScale(.medium)
                        Text(controller.isDeleting ? "Deleting…" : "Delete All Data")
                            .font(.body)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, Spacing.md)
                    .background(Color.semantic(.error).opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.semantic(.error).opacity(0.25), lineWidth: 1)
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(controller.isDeleting)
            }

            // Inline deletion scheduled with undo
            if controller.deleteScheduled {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(Color.semantic(.accent))
                    Text("Deletion in \(controller.deleteCountdown)s…")
                        .font(.subheadline)
                        .foregroundColor(.semantic(.textSecondary))
                    Spacer()
                    Button("Undo") { controller.undoDelete() }
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 6)
                        .background(Color.semantic(.bgSecondary))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.semantic(.separator).opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(Spacing.md)
                .background(Color.semantic(.fillSecondary))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.semantic(.bgSecondary))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.semantic(.separator).opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(12)
        .confirmationDialog(
            "Delete All Data?",
            isPresented: $controller.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                controller.scheduleDeleteAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all memos and related data. You can undo within a few seconds.")
        }
        .alert(item: $controller.alertItem) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
    }

    private func label(icon: String, title: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundColor(Color.semantic(.brandPrimary))
            Text(title)
                .font(.body)
                .foregroundColor(.semantic(.textPrimary))
            Spacer()
            Image(systemName: "arrow.up.right")
                .foregroundColor(.semantic(.textSecondary))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, Spacing.md)
        .background(Color.semantic(.bgSecondary))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.semantic(.separator).opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(10)
        .contentShape(Rectangle())
    }
}

#Preview {
    ScrollView {
        PrivacySectionView()
            .padding()
    }
    .background(Color.semantic(.bgPrimary))
}
