import SwiftUI

/// Consolidated processing control that maps to existing settings:
/// - Transcription service: UserDefaults.selectedTranscriptionService
/// - Local analysis toggle: AppConfiguration.shared.useLocalAnalysis
struct ProcessingOptionsSection: View {
    @StateObject private var appConfig = AppConfiguration.shared
    @State private var advancedExpanded = false
    @StateObject private var whisperDownloadManager = DIContainer.shared.modelDownloadManager()
    @StateObject private var localModelDownloadManager = LocalModelDownloadManager.shared
    @State private var showModelsStatus = false
    @State private var showWhisperAlert = false
    @State private var showAnalysisAlert = false

    enum ProcessingMode: String, CaseIterable {
        case cloud
        case device
        case hybrid // derived only (not selectable) when user customizes in Advanced
    }

    private var currentMode: ProcessingMode {
        let svc = UserDefaults.standard.selectedTranscriptionService
        let localAI = appConfig.useLocalAnalysis
        switch (svc, localAI) {
        case (.cloudAPI, false): return .cloud
        case (.localWhisperKit, true): return .device
        default: return .hybrid
        }
    }

    private func setMode(_ mode: ProcessingMode) {
        HapticManager.shared.playSelection()
        switch mode {
        case .cloud:
            UserDefaults.standard.selectedTranscriptionService = .cloudAPI
            appConfig.useLocalAnalysis = false
            AppConfiguration.shared.strictLocalWhisper = false
        case .device:
            UserDefaults.standard.selectedTranscriptionService = .localWhisperKit
            appConfig.useLocalAnalysis = true
            AppConfiguration.shared.strictLocalWhisper = true
        case .hybrid:
            // Not settable via picker; managed through advanced options
            break
        }
    }

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header + segmented control
                HStack(spacing: Spacing.md) {
                    Label("Processing", systemImage: "brain")
                        .font(SonoraDesignSystem.Typography.headingSmall)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { currentMode == .hybrid ? ProcessingMode.device : currentMode },
                        set: { setMode($0) }
                    )) {
                        Text("Cloud").tag(ProcessingMode.cloud)
                        Text("Device").tag(ProcessingMode.device)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                // Minimal disclosure with Learn more → full disclosure sheet
                AIDisclosureMinimal()

                // Trade-offs card
                ProcessingModeCard(mode: currentMode)

                // Advanced controls
                if advancedExpanded {
                    Divider().background(Color.semantic(.separator))

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Advanced Options")
                            .font(.subheadline)
                            .foregroundColor(.semantic(.textSecondary))

                        // Existing toggles surfaced explicitly for power users
                        Toggle("Use Local Transcription", isOn: Binding(
                            get: { UserDefaults.standard.selectedTranscriptionService == .localWhisperKit },
                            set: { isOn in
                                let target: TranscriptionServiceType = isOn ? .localWhisperKit : .cloudAPI
                                HapticManager.shared.playSelection()
                                UserDefaults.standard.selectedTranscriptionService = target
                                AppConfiguration.shared.strictLocalWhisper = (target == .localWhisperKit)
                                if isOn {
                                    // Pre-flight checks for Whisper model
                                    if !UserDefaults.standard.isSelectedTranscriptionServiceAvailable(downloadManager: whisperDownloadManager) {
                                        showWhisperAlert = true
                                    }
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .semantic(.brandPrimary)))

                        Toggle("Use Local Analysis", isOn: $appConfig.useLocalAnalysis)
                            .toggleStyle(SwitchToggleStyle(tint: .semantic(.brandPrimary)))
                            .onChange(of: appConfig.useLocalAnalysis) { _, enabled in
                                if enabled {
                                    let model = LocalModel(rawValue: appConfig.selectedLocalModel) ?? .defaultModel
                                    if !localModelDownloadManager.isModelReady(model) {
                                        showAnalysisAlert = true
                                    }
                                }
                            }

                        // Optional strict local switch — keep copy short for beta
                        Toggle("Prefer On‑Device Only", isOn: Binding(
                            get: { AppConfiguration.shared.strictLocalWhisper },
                            set: { AppConfiguration.shared.strictLocalWhisper = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .semantic(.brandPrimary)))
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))

                        // Compact model management (status + actions)
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Models")
                                .font(.subheadline)
                                .foregroundColor(.semantic(.textSecondary))

                            // Local transcription (WhisperKit)
                            WhisperModelCompactRow(downloadManager: whisperDownloadManager)

                            // Local analysis (Phi-4 Mini)
                            LocalAnalysisModelCompactRow(appConfig: appConfig, manager: localModelDownloadManager)

                            // Place Model Status control at the bottom, centered
                            HStack {
                                Spacer()
                                Button(action: { showModelsStatus = true }) {
                                    Label("Model Status", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                Spacer()
                            }
                            .padding(.top, Spacing.sm)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button(action: { withAnimation { advancedExpanded.toggle() } }) {
                    HStack(spacing: 6) {
                        Text(advancedExpanded ? "Hide Advanced" : "Show Advanced")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .rotationEffect(.degrees(advancedExpanded ? 180 : 0))
                    }
                    .foregroundColor(.semantic(.textSecondary))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showModelsStatus) { ModelsStatusView() }
                .sheet(isPresented: $showWhisperAlert) { whisperAlertView }
                .sheet(isPresented: $showAnalysisAlert) { analysisAlertView }
            }
        }
    }
}

// MARK: - Preflight Alerts

private extension ProcessingOptionsSection {
    var whisperAlertView: some View {
        let info = UserDefaults.standard.selectedWhisperModelInfo
        let size = info.size
        let available = StorageManager.availableFreeBytes().map { StorageManager.formatBytes($0) }
        let onWiFi = StorageManager.isOnWiFi()
        return ModelDownloadAlert(
            title: "Download \(info.displayName)?",
            modelName: info.displayName,
            sizeText: size,
            availableText: available,
            wifiRequired: !onWiFi,
            descriptionText: "This model enables on‑device transcription with full privacy.",
            onDownloadNow: {
                showWhisperAlert = false
                whisperDownloadManager.downloadModel(info.id)
            },
            onLater: { showWhisperAlert = false }
        )
    }

    var analysisAlertView: some View {
        let model = LocalModel(rawValue: appConfig.selectedLocalModel) ?? .defaultModel
        let size = model.approximateSize
        let available = StorageManager.availableFreeBytes().map { StorageManager.formatBytes($0) }
        let onWiFi = StorageManager.isOnWiFi()
        return ModelDownloadAlert(
            title: "Download \(model.displayName)?",
            modelName: model.displayName,
            sizeText: size,
            availableText: available,
            wifiRequired: !onWiFi,
            descriptionText: "On‑device analysis keeps your data private.",
            onDownloadNow: {
                showAnalysisAlert = false
                localModelDownloadManager.downloadModel(model)
            },
            onLater: { showAnalysisAlert = false }
        )
    }
}

// Trade-off visualization using existing semantic colors
struct ProcessingModeCard: View {
    let mode: ProcessingOptionsSection.ProcessingMode
    private var storageImpactText: String? {
        // Estimate combined storage requirement if device/hybrid
        let svc = UserDefaults.standard.selectedTranscriptionService
        let whisperSize = WhisperModelInfo.model(withId: UserDefaults.standard.selectedWhisperModel)?.size
        let analysisModel = LocalModel(rawValue: AppConfiguration.shared.selectedLocalModel) ?? .defaultModel
        var bytes: Int64 = 0
        if svc == .localWhisperKit, let size = whisperSize, let b = StorageManager.parseApproxSize(size) { bytes += b }
        if AppConfiguration.shared.useLocalAnalysis {
            // Approximate from LocalModel
            if let b = StorageManager.parseApproxSize(analysisModel.approximateSize) { bytes += b }
        }
        if bytes > 0 { return "Requires ~\(StorageManager.formatBytes(bytes)) storage" }
        return nil
    }

    private func prosForMode(_ mode: ProcessingOptionsSection.ProcessingMode) -> [String] {
        switch mode {
        case .cloud: return ["Faster processing", "Higher accuracy", "Latest models"]
        case .device: return ["Complete privacy", "Works offline", "No data leaves device"]
        case .hybrid: return ["Balanced approach", "Fallback options"]
        }
    }
    private func consForMode(_ mode: ProcessingOptionsSection.ProcessingMode) -> [String] {
        switch mode {
        case .cloud: return ["Requires internet", "Data sent to servers"]
        case .device:
            var items = ["Slower processing"]
            if let impact = storageImpactText { items.append(impact) } else { items.append("Uses device storage") }
            return items
        case .hybrid: return ["More to configure"]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(prosForMode(mode), id: \.self) { pro in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.semantic(.success))
                                .font(.caption)
                            Text(pro)
                                .font(.caption)
                                .foregroundColor(.semantic(.textPrimary))
                        }
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(consForMode(mode), id: \.self) { con in
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.semantic(.warning))
                                .font(.caption)
                            Text(con)
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                    }
                }
            }
            .padding(Spacing.sm)
            .background(Color.semantic(.fillSecondary))
            .cornerRadius(8)
        }
    }
}

// Minimal disclosure that opens the existing full disclosure view in a sheet
struct AIDisclosureMinimal: View {
    @State private var showFullDisclosure = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .foregroundColor(.semantic(.textSecondary))
                .font(.caption)
            Text("AI features use machine learning")
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
            Spacer()
            Button("Learn more") { showFullDisclosure = true }
                .font(.caption)
                .foregroundColor(.semantic(.brandPrimary))
        }
        .padding(.horizontal, 2)
        .sheet(isPresented: $showFullDisclosure) {
            ScrollView { AIDisclosureSectionView().padding() }
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Compact Rows

private struct WhisperModelCompactRow: View {
    @State private var showingSelection = false
    @State private var showDeleteConfirm = false
    @ObservedObject var downloadManager: ModelDownloadManager

    private var selected: WhisperModelInfo {
        return UserDefaults.standard.selectedWhisperModelInfo
    }
    private var state: ModelDownloadState { downloadManager.getDownloadState(for: selected.id) }
    private var progress: Double { downloadManager.getDownloadProgress(for: selected.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.md) {
                Label("Local Transcription", systemImage: "quote.bubble")
                    .font(.subheadline)
                Spacer()
                Button("Manage") { showingSelection = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            HStack(spacing: Spacing.sm) {
                Text(selected.displayName)
                    .font(.caption)
                    .foregroundColor(.semantic(.textPrimary))
                Text(selected.size)
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                Spacer()
                // Inline action button reflecting state
                inlineStatus
            }
            // Requirements text
            if state == .notDownloaded {
                HStack(spacing: 6) {
                    Image(systemName: "wifi").foregroundColor(.semantic(.warning))
                    Text("Wi‑Fi required • \(selected.size)")
                        .font(.caption2)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
            if state == .downloading {
                ProgressView(value: progress)
                    .tint(.semantic(.brandPrimary))
            }
        }
        .sheet(isPresented: $showingSelection) { WhisperModelSelectionView() }
    }

    @ViewBuilder private var inlineStatus: some View {
        switch state {
        case .notDownloaded:
            Button(action: { downloadManager.downloadModel(selected.id) }) {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .downloading:
            Button(action: { downloadManager.cancelDownload(for: selected.id) }) {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .downloaded:
            HStack(spacing: Spacing.sm) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.semantic(.success))
                   // Text("Ready").font(.caption).foregroundColor(.semantic(.success))
                }
                Button(role: .destructive, action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.semantic(.error))
                .accessibilityLabel("Delete model")
            }
            .alert("Delete \(selected.displayName)?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    downloadManager.deleteModel(selected.id)
                }
            } message: {
                Text("This frees storage. You can download it again later.")
            }
        case .failed:
            Button(action: { downloadManager.retryDownload(for: selected.id) }) {
                Label("Retry", systemImage: "arrow.clockwise.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .stale:
            Button(action: { downloadManager.forceRetryDownload(for: selected.id) }) {
                Label("Refresh", systemImage: "exclamationmark.triangle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

private struct LocalAnalysisModelCompactRow: View {
    @ObservedObject var appConfig: AppConfiguration
    @ObservedObject var manager: LocalModelDownloadManager
    @State private var presentManage = false

    private var model: LocalModel {
        return LocalModel(rawValue: appConfig.selectedLocalModel) ?? .defaultModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.md) {
                Label("Local Analysis", systemImage: "cpu")
                    .font(.subheadline)
                Spacer()
                NavigationLink(destination: ModelDownloadView(), isActive: $presentManage) { EmptyView() }
                    .hidden()
                Button("Manage") { presentManage = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            HStack(spacing: Spacing.sm) {
                Text(model.displayName)
                    .font(.caption)
                Text(model.approximateSize)
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                Spacer()
                inlineStatus
            }
            if !manager.isModelReady(model) {
                HStack(spacing: 6) {
                    Image(systemName: "wifi").foregroundColor(.semantic(.warning))
                    Text("Wi‑Fi required • \(model.approximateSize)")
                        .font(.caption2)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
            if manager.isDownloading(model) {
                ProgressView(value: Double(manager.downloadProgress(for: model)))
                    .tint(.semantic(.brandPrimary))
            }
        }
    }

    @ViewBuilder private var inlineStatus: some View {
        if manager.isModelReady(model) {
            HStack(spacing: Spacing.sm) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.semantic(.success))
                   // Text("Ready").font(.caption).foregroundColor(.semantic(.success))
                }
                Button(role: .destructive, action: { manager.deleteModel(model) }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.semantic(.error))
                .accessibilityLabel("Delete model")
            }
        } else if manager.isDownloading(model) {
            Button(action: { manager.cancelDownload(for: model) }) {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else {
            Button(action: { manager.downloadModel(model) }) {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!model.isDeviceCompatible)
        }
    }
}
