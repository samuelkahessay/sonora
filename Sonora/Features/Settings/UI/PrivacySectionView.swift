import SwiftUI

struct PrivacySectionView: View {
    @StateObject private var controller = PrivacyController()

    private let privacyURL = URL(string: "https://samuelkahessay.github.io/sonora/privacy-policy.html")!
    private let termsURL = URL(string: "https://samuelkahessay.github.io/sonora/terms-of-service.html")!
    private let supportURL = URL(string: "https://samuelkahessay.github.io/sonora/support.html")!

    var body: some View {
        SettingsCard {
            Text("Privacy & Data")
                .font(SonoraDesignSystem.Typography.headingSmall)
                .accessibilityAddTraits(.isHeader)

            // Links (stacked)
            VStack(spacing: Spacing.md) {
                Link(destination: privacyURL) {
                    label(icon: "hand.raised.fill", title: "Privacy Policy")
                }
                .accessibilityLabel("Privacy Policy")
                .accessibilityHint("Double tap to open Privacy Policy in your browser")
                .accessibilityAddTraits(.isLink)
                .onTapGesture {
                    HapticManager.shared.playSelection()
                }
                
                Link(destination: termsURL) {
                    label(icon: "doc.text.fill", title: "Terms of Service")
                }
                .accessibilityLabel("Terms of Service")
                .accessibilityHint("Double tap to open Terms of Service in your browser")
                .accessibilityAddTraits(.isLink)
                .onTapGesture {
                    HapticManager.shared.playSelection()
                }

                Link(destination: supportURL) {
                    label(icon: "questionmark.circle.fill", title: "Support")
                }
                .accessibilityLabel("Support")
                .accessibilityHint("Double tap to open Support in your browser")
                .accessibilityAddTraits(.isLink)
                .onTapGesture {
                    HapticManager.shared.playSelection()
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
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: 0) {
                        optionRow(title: "Memos", binding: $controller.exportMemos)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Include memos in export")
                            .accessibilityValue(controller.exportMemos ? "enabled" : "disabled")
                            .accessibilityHint("Double tap to toggle including audio memos in data export")
                            
                        Divider().background(Color.semantic(.separator))
                            .accessibilityHidden(true)
                            
                        optionRow(title: "Transcripts", binding: $controller.exportTranscripts)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Include transcripts in export")
                            .accessibilityValue(controller.exportTranscripts ? "enabled" : "disabled")
                            .accessibilityHint("Double tap to toggle including transcription text in data export")
                            
                        Divider().background(Color.semantic(.separator))
                            .accessibilityHidden(true)
                            
                        optionRow(title: "Analysis", binding: $controller.exportAnalysis)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Include analysis in export")
                            .accessibilityValue(controller.exportAnalysis ? "enabled" : "disabled")
                            .accessibilityHint("Double tap to toggle including AI analysis results in data export")
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.semantic(.separator).opacity(0.45), lineWidth: 1)
                    )
                    .cornerRadius(10)
                }
                Button(action: { 
                    HapticManager.shared.playSelection()
                    Task { await controller.exportData() } 
                }) {
                    HStack(spacing: Spacing.md) {
                        if controller.isExporting { 
                            LoadingIndicator(size: .small)
                                .accessibilityLabel("Exporting in progress")
                        }
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
                .accessibilityLabel(controller.isExporting ? "Exporting data" : "Export data")
                .accessibilityHint(controller.isExporting ? "Data export is in progress" : "Double tap to export selected data types to share sheet")
                .accessibilityAddTraits(controller.isExporting ? [.updatesFrequently] : [])

                Button(role: .destructive, action: { 
                    HapticManager.shared.playWarning()
                    controller.requestDeleteAll() 
                }) {
                    HStack(spacing: Spacing.md) {
                        if controller.isDeleting { 
                            LoadingIndicator(size: .small)
                                .accessibilityLabel("Deleting in progress")
                        }
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
                .accessibilityLabel(controller.isDeleting ? "Deleting all data" : "Delete all data")
                .accessibilityHint(controller.isDeleting ? "Data deletion is in progress" : "Double tap to permanently delete all memos, transcripts, and analysis")
                .accessibilityAddTraits(controller.isDeleting ? [.updatesFrequently] : [])
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
                .font(SonoraDesignSystem.Typography.bodyLarge)
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
                .font(SonoraDesignSystem.Typography.bodyLarge)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .onChange(of: binding.wrappedValue) { _, _ in
                    HapticManager.shared.playSelection()
                }
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
