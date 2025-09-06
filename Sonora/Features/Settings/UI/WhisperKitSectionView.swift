import SwiftUI

struct WhisperKitSectionView: View {
    @State private var showingModelSelection = false
    @State private var showingModelDiagnostics = false
    @State private var showingAdvanced = false
    @StateObject private var downloadManager = DIContainer.shared.modelDownloadManager()
    @State private var selectedModelId: String = UserDefaults.standard.selectedWhisperModel
    @State private var normalizationMessage: String? = nil
    
    private var selectedModel: WhisperModelInfo {
        WhisperModelInfo.model(withId: selectedModelId) ?? UserDefaults.standard.selectedWhisperModelInfo
    }
    
    private var selectedModelDownloadState: ModelDownloadState {
        downloadManager.getDownloadState(for: selectedModel.id)
    }
    
    @State private var eventSubscriptionId: UUID? = nil

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Transcription service toggle
                TranscriptionServiceToggle(downloadManager: downloadManager)
                
                Divider()
                    .background(Color.semantic(.separator))
                
                // Model selection section header
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.semantic(.brandPrimary))
                        .font(.title3)
                    
                    Text("WhisperKit Models")
                        .font(SonoraDesignSystem.Typography.headingSmall)
                        .fontWeight(.semibold)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("WhisperKit Models")
                .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Download and manage local AI models for offline transcription. Models provide different trade-offs between speed, accuracy, and storage size.")
                        .font(.subheadline)
                        .foregroundColor(.semantic(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Current model selection
                Button(action: {
                    HapticManager.shared.playSelection()
                    showingModelSelection = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Selected Model")
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                            
                            HStack {
                                Text(selectedModel.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.semantic(.textPrimary))
                                
                                Text("(\(selectedModel.size))")
                                    .font(.caption)
                                    .foregroundColor(.semantic(.textSecondary))
                                
                                Spacer()
                                
                                // Download status indicator
                                HStack(spacing: 4) {
                                    Image(systemName: downloadStatusIcon)
                                        .font(.caption)
                                        .foregroundColor(downloadStatusColor)
                                    
                                    Text(selectedModelDownloadState.displayName)
                                        .font(.caption)
                                        .foregroundColor(downloadStatusColor)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                    }
                    .padding(Spacing.md)
                    .background(Color.semantic(.fillSecondary))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Selected model: \(selectedModel.displayName), \(selectedModel.size)")
                .accessibilityHint("Double tap to change the selected Whisper model")

                // Info section
                HStack(alignment: .top, spacing: Spacing.md) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.semantic(.textSecondary))
                        .font(.caption)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Models are downloaded when first used. You can manage downloaded models and view storage usage in the model selection screen.")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Information: Models are downloaded when first used. You can manage downloaded models and view storage usage in the model selection screen.")
                .accessibilityAddTraits(.isStaticText)

                // Health check + Diagnostics + Advanced + Strict local toggle
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Button(action: verifyLocalSetup) {
                        Label("Verify Local Setup", systemImage: "stethoscope")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: { showingModelDiagnostics = true }) {
                        Label("Diagnostics", systemImage: "wrench.and.screwdriver")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: { showingAdvanced = true }) {
                        Label("Advanced", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Toggle("Disable Cloud Fallback", isOn: Binding(
                            get: { AppConfiguration.shared.strictLocalWhisper },
                            set: { AppConfiguration.shared.strictLocalWhisper = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .semantic(.brandPrimary)))
                        .font(.caption)
                        
                        Spacer()
                    }
                }
            }
        }
        .onAppear { selectedModelId = UserDefaults.standard.selectedWhisperModel }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            selectedModelId = UserDefaults.standard.selectedWhisperModel
        }
        .onAppear {
            // Subscribe to model normalization events
            eventSubscriptionId = EventBus.shared.subscribe(to: AppEvent.self) { event in
                switch event {
                case .whisperModelNormalized(_, let normalized):
                    let display = WhisperModelInfo.model(withId: normalized)?.displayName ?? normalized
                    normalizationMessage = "Selected model changed to installed: \(display)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { normalizationMessage = nil }
                default:
                    break
                }
            }
        }
        .onDisappear {
            if let id = eventSubscriptionId { EventBus.shared.unsubscribe(id) }
            eventSubscriptionId = nil
        }
        .sheet(isPresented: $showingModelSelection) { WhisperModelSelectionView() }
        .sheet(isPresented: $showingModelDiagnostics) { WhisperKitDiagnosticsView() }
        .sheet(isPresented: $showingAdvanced) { WhisperKitAdvancedView() }
        .overlay(alignment: .top) {
            if let msg = normalizationMessage {
                Text(msg)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.semantic(.brandPrimary).opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Actions
    @MainActor private func verifyLocalSetup() {
        Task {
            let checker = WhisperKitHealthChecker()
            let report = await checker.checkSelectedModel()
            normalizationMessage = report.ok ? "WhisperKit OK: \(report.details)" : "WhisperKit Issue: \(report.details)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { normalizationMessage = nil }
        }
    }
    
    // MARK: - Download Status Properties
    
    private var downloadStatusIcon: String {
        switch selectedModelDownloadState {
        case .notDownloaded: return "arrow.down.circle"
        case .downloading: return "arrow.down.circle.fill"
        case .downloaded: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .stale: return "exclamationmark.triangle.circle"
        }
    }
    
    private var downloadStatusColor: Color {
        switch selectedModelDownloadState {
        case .notDownloaded: return .semantic(.textSecondary)
        case .downloading: return .semantic(.brandPrimary)
        case .downloaded: return .semantic(.success)
        case .failed: return .semantic(.error)
        case .stale: return .semantic(.error)
        }
    }
}

#Preview {
    WhisperKitSectionView()
        .padding()
}
