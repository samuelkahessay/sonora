import SwiftUI
import UIKit

struct WhisperKitDiagnosticsView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var selectedModelId: String = UserDefaults.standard.selectedWhisperModel
    @State private var resolvedFolder: URL? = nil
    @State private var folderItems: [String] = []
    @State private var mlmodelcItems: [String] = []
    @State private var tokenizerItems: [String] = []
    @State private var installedIds: [String] = []
    @State private var healthStatus: String? = nil
    @State private var healthOK: Bool? = nil
    @State private var isRunningHealthCheck = false

    private let modelProvider = DIContainer.shared.whisperKitModelProvider()
    private let downloadManager = DIContainer.shared.modelDownloadManager()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    header
                    diagnosticsCard
                    actions
                }
                .padding(.horizontal)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.semantic(.bgPrimary).ignoresSafeArea())
            .navigationTitle("Local Engine Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { refresh() }
    }

    @ViewBuilder private var header: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "waveform")
                        .foregroundColor(.semantic(.brandPrimary))
                        .font(.title2)
                    Text("Inspect your local WhisperKit setup")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                Text("Shows the resolved model folder, important assets, and a quick health test. Use this to troubleshoot local transcription.")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
            }
        }
    }

    @ViewBuilder private var diagnosticsCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Selected Model")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                    Spacer()
                    Text(selectedModelId)
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }

                if let folder = resolvedFolder {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Resolved Folder")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                        HStack(alignment: .top) {
                            Text(folder.path)
                                .font(.footnote)
                                .foregroundColor(.semantic(.textPrimary))
                                .textSelection(.enabled)
                            Spacer()
                            Button(action: { UIPasteboard.general.string = folder.path }) {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.semantic(.brandPrimary))
                            .accessibilityLabel("Copy path")
                        }
                    }
                } else {
                    Text("Resolved Folder: not found")
                        .font(.caption)
                        .foregroundColor(.semantic(.error))
                }

                Divider().background(Color.semantic(.separator))

                HStack {
                    Text("Installed IDs (") + Text("\(installedIds.count)") + Text(")")
                    Spacer()
                    Text(installedIds.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.semantic(.textSecondary))
                        .lineLimit(2)
                }

                if !mlmodelcItems.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compiled Models (.mlmodelc): \(mlmodelcItems.count)")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                        Text(mlmodelcItems.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tokenizer Assets: \(tokenizerItems.isEmpty ? "missing" : String(tokenizerItems.count))")
                        .font(.caption)
                        .foregroundColor(tokenizerItems.isEmpty ? .semantic(.error) : .semantic(.textSecondary))
                    if !tokenizerItems.isEmpty {
                        Text(tokenizerItems.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                }

                if !folderItems.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Folder Items (") + Text("\(folderItems.count)") + Text(")")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                        Text(folderItems.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.semantic(.textSecondary))
                            .lineLimit(4)
                    }
                }

                if let ok = healthOK, let status = healthStatus {
                    HStack(spacing: 8) {
                        Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(ok ? .semantic(.success) : .semantic(.error))
                        Text(status)
                            .font(.footnote)
                            .foregroundColor(ok ? .semantic(.success) : .semantic(.error))
                    }
                    .padding(.top, Spacing.sm)
                }
            }
        }
    }

    @ViewBuilder private var actions: some View {
        HStack {
            Button(action: runHealthCheck) {
                if isRunningHealthCheck {
                    ProgressView().progressViewStyle(.circular)
                } else {
                    Label("Run Health Check", systemImage: "stethoscope")
                }
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(role: .destructive, action: repairSelected) {
                Label("Repair Selected Model", systemImage: "wrench.and.screwdriver")
            }
            .buttonStyle(.bordered)
        }
        HStack {
            Button(action: refresh) {
                Label("Rescan Folders", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    private func refresh() {
        selectedModelId = UserDefaults.standard.selectedWhisperModel
        installedIds = modelProvider.installedModelIds()
        resolvedFolder = modelProvider.installedModelFolder(id: selectedModelId)
        folderItems = []
        mlmodelcItems = []
        tokenizerItems = []
        if let folder = resolvedFolder {
            if let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                folderItems = items.map { $0.lastPathComponent }
            }
            // Walk for mlmodelc and tokenizer assets
            if let en = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                while let obj = en.nextObject() as? URL {
                    let n = obj.lastPathComponent
                    if obj.pathExtension == "mlmodelc" { mlmodelcItems.append(n) }
                    let l = n.lowercased()
                    if l == "tokenizer.json" || l == "tokenizer.model" || l == "vocabulary.json" || l.contains("merges") || l.contains("vocab") || l.contains("tokenizer") {
                        tokenizerItems.append(n)
                    }
                }
            }
        }
    }

    private func runHealthCheck() {
        isRunningHealthCheck = true
        healthStatus = nil
        healthOK = nil
        Task { @MainActor in
            let checker = WhisperKitHealthChecker()
            let report = await checker.checkSelectedModel()
            healthOK = report.ok
            healthStatus = report.details
            isRunningHealthCheck = false
        }
    }

    private func repairSelected() {
        downloadManager.repairModel(selectedModelId)
    }
}

#Preview {
    WhisperKitDiagnosticsView()
}
