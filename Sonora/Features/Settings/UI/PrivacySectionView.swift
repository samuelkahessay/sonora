import SwiftUI

struct PrivacySectionView: View {
    @StateObject private var controller = PrivacyController()

    private let privacyURL = URL(string: "https://sonora.app/privacy")!
    private let termsURL = URL(string: "https://sonora.app/terms")!

    var body: some View {
        SettingsCard {
            Text("Privacy & Data")
                .font(.headline)

            // Links (stacked)
            VStack(spacing: Spacing.md) {
                // TODO: Replace with real Privacy Policy link
                Link(destination: privacyURL) {
                    label(icon: "hand.raised.fill", title: "Privacy Policy")
                }
                // TODO: Replace with real Terms of Use link
                Link(destination: termsURL) {
                    label(icon: "doc.text.fill", title: "Terms of Use")
                }
            }

            // Actions
            VStack(spacing: Spacing.md) {
                // Export options
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Export Options")
                        .font(.subheadline)
                        .foregroundColor(.semantic(.textSecondary))
                        .padding(.horizontal, Spacing.sm)

                    VStack(spacing: 0) {
                        optionRow(title: "Memos", binding: $controller.exportMemos)
                        Divider().background(Color.semantic(.separator))
                        optionRow(title: "Transcripts", binding: $controller.exportTranscripts)
                        Divider().background(Color.semantic(.separator))
                        optionRow(title: "Analysis", binding: $controller.exportAnalysis)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.semantic(.separator).opacity(0.45), lineWidth: 1)
                    )
                    .cornerRadius(10)
                }
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.semantic(.separator).opacity(0.45), lineWidth: 1)
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(controller.isExporting || controller.isDeleting || !controller.canExport)
                .opacity((controller.canExport && !controller.isExporting) ? 1.0 : 0.6)

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
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.semantic(.error).opacity(0.55), lineWidth: 1))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(controller.isDeleting)
            }

            // No inline deletion banner; action is confirmed and immediate
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
        .alert(item: $controller.alertItem) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $controller.isPresentingShareSheet, onDismiss: {
            // Cleanup after share sheet is dismissed
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
        .contentShape(Rectangle())
    }
    private func optionRow(title: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: Spacing.md) {
            Text(title)
                .font(.body)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, Spacing.md)
    }
}

#Preview {
    ScrollView {
        PrivacySectionView()
            .padding()
    }
    .background(Color.semantic(.bgPrimary))
}
