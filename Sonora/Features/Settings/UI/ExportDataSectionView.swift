import SwiftUI

/// Non-destructive export options in their own card.
struct ExportDataSectionView: View {
    @StateObject private var controller = PrivacyController()

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Export Data", systemImage: "square.and.arrow.up.on.square")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Button { controller.presentExportSheet() } label: {
                        HStack(spacing: Spacing.sm) {
                            Text("Create Export")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.semantic(.textPrimary))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.semantic(.textTertiary))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Choose which data to include and share the export bundle")

                    Text("Make a shareable ZIP with transcripts, analysis, or audio.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
        }
        .alert(item: $controller.alertItem) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $controller.isPresentingExportSheet, onDismiss: {
            controller.isPresentingExportSheet = false
        }) {
            ExportDataSheetView(controller: controller)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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

private struct ExportDataSheetView: View {
    @ObservedObject var controller: PrivacyController
    @SwiftUI.Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Mix and match the data you'd like to take with you.")
                        .font(.body)
                        .foregroundColor(.semantic(.textPrimary))

                    VStack(spacing: Spacing.sm) {
                        exportToggle(
                            isOn: $controller.exportMemos,
                            available: controller.memosAvailable,
                            title: "Audio & Memos",
                            subtitle: "Original recordings and metadata",
                            icon: "waveform"
                        )

                        exportToggle(
                            isOn: $controller.exportTranscripts,
                            available: controller.transcriptsAvailable,
                            title: "Transcripts",
                            subtitle: "Text copies of every memo",
                            icon: "text.alignleft"
                        )

                        exportToggle(
                            isOn: $controller.exportAnalysis,
                            available: controller.analysisAvailable,
                            title: "Analysis",
                            subtitle: "AI summaries, themes, and action items",
                            icon: "sparkles"
                        )
                    }

                    if !controller.hasDataToExport {
                        Text("No memos, transcripts, or analysis found yet.")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Spacing.sm)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if controller.isExporting {
                        HStack(spacing: Spacing.sm) {
                            ProgressView()
                            Text("Preparing your export…")
                                .font(.subheadline)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Button {
                        Task { await controller.exportData() }
                    } label: {
                        Text(controller.isExporting ? "Preparing…" : "Create Export")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.isExporting || !controller.canExport)

                    Text("Exports save to a single ZIP file you can share anywhere.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textTertiary))
                }
            }
            .padding(Spacing.lg)
            .background(Color.semantic(.bgSecondary))
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        controller.isPresentingExportSheet = false
                        dismiss()
                    }
                }
            }
        }
    }

    private func exportToggle(
        isOn: Binding<Bool>,
        available: Bool,
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.semantic(.brandPrimary))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.semantic(.textPrimary))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .semantic(.brandPrimary)))
        .disabled(!available)
        .opacity(available ? 1 : 0.4)
        .accessibilityHint(available ? "Include in export" : "No data available")
    }
}

#Preview {
    ExportDataSectionView()
}
