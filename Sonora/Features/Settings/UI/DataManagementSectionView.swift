import SwiftUI
import UniformTypeIdentifiers

struct DataManagementSectionView: View {
    @StateObject private var controller = PrivacyController()
    @State private var isImporting = false
    @State private var showImportSuccess = false
    @State private var importErrorMessage: String?

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Data Management", systemImage: "internaldrive")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Button {
                        controller.presentExportSheet()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Label("Export Data", systemImage: "square.and.arrow.up.on.square")
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

                    Text("Create a shareable backup with transcripts, analysis, or audio recordings.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }

                Divider().background(Color.semantic(.separator))

                // Import voice memos
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Button {
                        isImporting = true
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Label("Import Voice Memos", systemImage: "square.and.arrow.down")
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
                    .accessibilityHint("Select an audio file to import as a memo")

                    Text("Add audio from Files: m4a, mp3, wav, aiff")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }

                if showImportSuccess {
                    NotificationBanner.success(message: "Imported memo") {
                        showImportSuccess = false
                    }
                }
                if let msg = importErrorMessage {
                    NotificationBanner(type: .error, message: msg) {
                        importErrorMessage = nil
                    }
                }
            }
        }
        .sheet(isPresented: $controller.isPresentingExportSheet, onDismiss: {
            controller.isPresentingExportSheet = false
        }) {
            ExportDataSheet(controller: controller)
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
        .sheet(isPresented: $isImporting) {
            AudioImportPicker { url in
                importURL(url)
                isImporting = false
            }
            .ignoresSafeArea()
        }
    }
}

private struct ExportDataSheet: View {
    @ObservedObject var controller: PrivacyController
    @SwiftUI.Environment(\.dismiss) private var dismiss

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

// MARK: - Import Helpers
extension DataManagementSectionView {
    private func importURL(_ url: URL) {
        let needsStop = url.startAccessingSecurityScopedResource()
        Task { @MainActor in
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
            do {
                let memoRepository = DIContainer.shared.memoRepository()
                let useCase = HandleNewRecordingUseCase(
                    memoRepository: memoRepository,
                    eventBus: DIContainer.shared.eventBus()
                )
                let memo = try await useCase.execute(at: url)
                let base = url.deletingPathExtension().lastPathComponent
                if !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let rename = RenameMemoUseCase(memoRepository: memoRepository)
                    try? await rename.execute(memo: memo, newTitle: base)
                }
                showImportSuccess = true
                importErrorMessage = nil
            } catch {
                importErrorMessage = ErrorMapping.mapError(error).errorDescription
                showImportSuccess = false
            }
        }
    }
}
