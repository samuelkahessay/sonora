import SwiftUI

/// A simple, focused screen that shows the two beta models with accurate status,
/// progress, on-disk size and management actions.
struct ModelsStatusView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var whisperManager = DIContainer.shared.modelDownloadManager()
    private let provider = DIContainer.shared.whisperKitModelProvider()
    @StateObject private var localManager = LocalModelDownloadManager.shared

    private let whisperId = WhisperModelInfo.availableModels.first { $0.id == "openai_whisper-large-v3" }?.id ?? "openai_whisper-large-v3"
    private let whisperDisplay = "WhisperKit • Large v3"
    private let localModel: LocalModel = .phi4_mini

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // WhisperKit card
                    SettingsCard {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Label("Local Transcription", systemImage: "brain.head.profile")
                                .font(SonoraDesignSystem.Typography.headingSmall)

                            statusRow_Whisper()
                            progressRow_Whisper()
                            infoRow_Whisper()
                            actionsRow_Whisper()
                        }
                    }

                    // Local Analysis card
                    SettingsCard {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Label("Local Analysis", systemImage: "cpu")
                                .font(SonoraDesignSystem.Typography.headingSmall)

                            statusRow_Local()
                            progressRow_Local()
                            infoRow_Local()
                            actionsRow_Local()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.semantic(.bgPrimary).ignoresSafeArea())
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { whisperManager.reconcileInstallStates(); localManager.refreshModelStatus() }
        }
    }

    // MARK: - Whisper helpers
    private func whisperState() -> ModelDownloadState { whisperManager.getDownloadState(for: whisperId) }
    private func whisperProgress() -> Double { whisperManager.getDownloadProgress(for: whisperId) }
    private func whisperExpectedBytes() -> Int64? {
        WhisperKitModelProvider.curatedModels.first(where: { $0.id == whisperId })?.sizeBytes
    }
    private func whisperOnDiskBytes() -> Int64? {
        guard let folder = provider.installedModelFolder(id: whisperId) else { return nil }
        return folderSize(folder)
    }

    // MARK: - Local model helpers
    private func localIsReady() -> Bool { localManager.isModelReady(localModel) }
    private func localIsDownloading() -> Bool { localManager.isDownloading(localModel) }
    private func localProgress() -> Double { Double(localManager.downloadProgress(for: localModel)) }
    private func localOnDiskBytes() -> Int64? {
        let root = localModel.localPath.deletingLastPathComponent()
        // Best-effort: sum GGUF files that contain a recognizable token for this model
        let token = "phi-4-mini"
        return folderSize(root, filter: { $0.lastPathComponent.lowercased().contains(token) && $0.pathExtension.lowercased() == "gguf" })
    }
    private func localApproxSizeString() -> String { localModel.approximateSize }

    // MARK: - Rows
    @ViewBuilder private func statusRow_Whisper() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(whisperDisplay).font(.subheadline).fontWeight(.medium)
                Text(whisperStatusText()).font(.caption).foregroundColor(.semantic(.textSecondary))
            }
            Spacer()
            statusBadge(for: whisperState())
        }
    }
    @ViewBuilder private func progressRow_Whisper() -> some View {
        if whisperState() == .downloading {
            ProgressView(value: whisperProgress()).tint(.semantic(.brandPrimary))
        }
    }
    @ViewBuilder private func infoRow_Whisper() -> some View {
        HStack(spacing: Spacing.md) {
            if let exp = whisperExpectedBytes() {
                infoPill(icon: "arrow.down.circle", text: "Size: \(formatBytes(exp))")
            }
            if let used = whisperOnDiskBytes() {
                infoPill(icon: "internaldrive", text: "On disk: \(formatBytes(used))")
            }
            Spacer()
        }
    }
    @ViewBuilder private func actionsRow_Whisper() -> some View {
        HStack(spacing: Spacing.sm) {
            switch whisperState() {
            case .notDownloaded:
                Button(action: { whisperManager.downloadModel(whisperId) }) {
                    Label("Download", systemImage: "arrow.down.circle")
                }.buttonStyle(.borderedProminent)
            case .downloading:
                Button(action: { whisperManager.cancelDownload(for: whisperId) }) {
                    Label("Cancel", systemImage: "xmark.circle")
                }.buttonStyle(.bordered)
            case .downloaded:
                Button(role: .destructive, action: { whisperManager.deleteModel(whisperId) }) {
                    Label("Delete", systemImage: "trash")
                }.buttonStyle(.bordered)
            case .failed:
                Button(action: { whisperManager.retryDownload(for: whisperId) }) {
                    Label("Retry", systemImage: "arrow.clockwise.circle")
                }.buttonStyle(.borderedProminent)
            case .stale:
                Button(action: { whisperManager.forceRetryDownload(for: whisperId) }) {
                    Label("Refresh", systemImage: "exclamationmark.triangle")
                }.buttonStyle(.bordered)
            }
            Spacer()
        }
    }

    @ViewBuilder private func statusRow_Local() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Phi‑4 Mini").font(.subheadline).fontWeight(.medium)
                Text(localIsReady() ? "Ready" : (localIsDownloading() ? "Downloading…" : "Not downloaded")).font(.caption).foregroundColor(.semantic(.textSecondary))
            }
            Spacer()
            if localIsReady() { readyBadge } else if localIsDownloading() { downloadingBadge } else { notReadyBadge }
        }
    }
    @ViewBuilder private func progressRow_Local() -> some View {
        if localIsDownloading() {
            ProgressView(value: localProgress()).tint(.semantic(.brandPrimary))
        }
    }
    @ViewBuilder private func infoRow_Local() -> some View {
        HStack(spacing: Spacing.md) {
            infoPill(icon: "arrow.down.circle", text: "Size: \(localApproxSizeString())")
            if let used = localOnDiskBytes() { infoPill(icon: "internaldrive", text: "On disk: \(formatBytes(used))") }
            Spacer()
        }
    }
    @ViewBuilder private func actionsRow_Local() -> some View {
        HStack(spacing: Spacing.sm) {
            if localIsReady() {
                Button(role: .destructive, action: { localManager.deleteModel(localModel) }) {
                    Label("Delete", systemImage: "trash")
                }.buttonStyle(.bordered)
            } else if localIsDownloading() {
                Button(action: { localManager.cancelDownload(for: localModel) }) {
                    Label("Cancel", systemImage: "xmark.circle")
                }.buttonStyle(.bordered)
            } else {
                Button(action: { localManager.downloadModel(localModel) }) {
                    Label("Download", systemImage: "arrow.down.circle")
                }.buttonStyle(.borderedProminent)
                .disabled(!localModel.isDeviceCompatible)
            }
            Spacer()
        }
    }

    // MARK: - UI helpers
    private func statusBadge(for state: ModelDownloadState) -> some View {
        switch state {
        case .downloaded:
            return AnyView(readyBadge)
        case .downloading:
            return AnyView(downloadingBadge)
        case .failed, .stale:
            return AnyView(warningBadge)
        case .notDownloaded:
            return AnyView(notReadyBadge)
        }
    }
    private var readyBadge: some View { Label("Ready", systemImage: "checkmark.circle.fill").font(.caption).foregroundColor(.semantic(.success)) }
    private var downloadingBadge: some View { Label("Downloading", systemImage: "arrow.down.circle.fill").font(.caption).foregroundColor(.semantic(.brandPrimary)) }
    private var warningBadge: some View { Label("Attention", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.semantic(.warning)) }
    private var notReadyBadge: some View { Label("Not Ready", systemImage: "arrow.down.circle").font(.caption).foregroundColor(.semantic(.textSecondary)) }

    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption)
            Text(text).font(.caption)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.semantic(.fillSecondary))
        .cornerRadius(6)
    }

    private func whisperStatusText() -> String {
        switch whisperState() {
        case .notDownloaded: return "Not downloaded"
        case .downloading: return "Downloading… \(Int(whisperProgress() * 100))%"
        case .downloaded: return "Ready"
        case .failed: return "Download failed"
        case .stale: return "Download stuck"
        }
    }

    private func folderSize(_ url: URL, filter: ((URL) -> Bool)? = nil) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        if let en = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in en {
                if let filter = filter, !filter(fileURL) { continue }
                do {
                    let attrs = try fm.attributesOfItem(atPath: fileURL.path)
                    if let size = attrs[.size] as? NSNumber { total += size.int64Value }
                } catch { continue }
            }
        }
        return total
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
