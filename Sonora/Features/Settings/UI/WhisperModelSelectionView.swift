import SwiftUI

struct WhisperModelSelectionView: View {
    @State private var selectedModelId: String = UserDefaults.standard.selectedWhisperModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager: ModelDownloadManager
    @State private var models: [WhisperModelInfo] = []
    @State private var isLoadingModels: Bool = true

    init() {
        let manager = DIContainer.shared.modelDownloadManager()
        _downloadManager = StateObject(wrappedValue: manager)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headerSection
                    if isLoadingModels {
                        ProgressView("Loading models...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        modelListSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.semantic(.bgPrimary).ignoresSafeArea())
            .navigationTitle("Whisper Model")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.semantic(.bgPrimary), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadModels()
        }
        .onAppear {
            // Perform reconciliation after view appears to avoid publishing during view updates
            DispatchQueue.main.async {
                downloadManager.reconcileInstallStates()
            }
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.semantic(.brandPrimary))
                        .font(.title2)
                    
                    Text("Local AI Models")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Local AI Models")
                .accessibilityAddTraits(.isHeader)
                
                Text("Choose a WhisperKit model for offline transcription. Larger models provide better accuracy but require more storage and processing time.")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.semantic(.textSecondary))
                        .accessibilityHidden(true)
                    
                    Text("Models will be downloaded when first used.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Information: Models will be downloaded when first used.")
            }
        }
    }
    
    // MARK: - Model List Section
    
    @ViewBuilder
    private var modelListSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Available Models")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                
                VStack(spacing: Spacing.md) {
                    ForEach(models, id: \.id) { model in
                        ModelRowView(
                            model: model,
                            isSelected: selectedModelId == model.id,
                            downloadManager: downloadManager
                        ) {
                            selectModel(model)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func selectModel(_ model: WhisperModelInfo) {
        HapticManager.shared.playSelection()
        selectedModelId = model.id
        UserDefaults.standard.selectedWhisperModel = model.id
        Logger.shared.info("Selected WhisperKit model: \(model.displayName) (\(model.id))")
    }

    // MARK: - Load Models
    private func loadModels() async {
        isLoadingModels = true
        defer { isLoadingModels = false }
        let provider = DIContainer.shared.whisperKitModelProvider()
        do {
            let available = try await provider.listAvailableModels()
            let mapped = available.map { mapToUIModel($0) }
            await MainActor.run { self.models = mapped }
        } catch {
            Logger.shared.error("Failed to load WhisperKit models: \(error.localizedDescription)", category: .system, context: nil, error: error)
            let curated = WhisperKitModelProvider.curatedModels.map { mapToUIModel($0) }
            await MainActor.run { self.models = curated }
        }
    }

    private func mapToUIModel(_ model: WhisperModel) -> WhisperModelInfo {
        let sizeString: String
        if let bytes = model.sizeBytes {
            sizeString = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        } else {
            sizeString = "Unknown size"
        }
        let idLower = model.id.lowercased()
        let speed: WhisperModelInfo.ModelPerformance
        let accuracy: WhisperModelInfo.ModelPerformance
        if idLower.contains("tiny") {
            speed = .veryHigh; accuracy = .low
        } else if idLower.contains("base") {
            speed = .high; accuracy = .medium
        } else if idLower.contains("small") {
            speed = .medium; accuracy = .high
        } else if idLower.contains("medium") || idLower.contains("large") {
            speed = .low; accuracy = .veryHigh
        } else {
            speed = .medium; accuracy = .medium
        }
        return WhisperModelInfo(
            id: model.id,
            displayName: model.displayName,
            size: sizeString,
            description: model.description,
            speedRating: speed,
            accuracyRating: accuracy
        )
    }
}

// MARK: - Model Row View

private struct ModelRowView: View {
    let model: WhisperModelInfo
    let isSelected: Bool
    @ObservedObject var downloadManager: ModelDownloadManager
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Model selection row
            Button(action: onSelect) {
                HStack(spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text(model.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.semantic(.textPrimary))
                            
                            Spacer()
                            
                            Text(model.size)
                                .font(.caption)
                                .foregroundColor(.semantic(.textSecondary))
                        }
                        
                        Text(model.description)
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: Spacing.lg) {
                            PerformanceIndicator(
                                label: "Speed",
                                rating: model.speedRating,
                                icon: "speedometer"
                            )
                            
                            PerformanceIndicator(
                                label: "Accuracy", 
                                rating: model.accuracyRating,
                                icon: "target"
                            )
                        }
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.semantic(.brandPrimary))
                            .font(.title3)
                            .accessibilityLabel("Selected")
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.semantic(.separator))
                            .font(.title3)
                            .accessibilityHidden(true)
                    }
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.semantic(.brandPrimary).opacity(0.1) : Color.semantic(.fillSecondary))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.semantic(.brandPrimary).opacity(0.3) : Color.semantic(.separator).opacity(0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(model.displayName) model, \(model.size), \(model.description)")
            .accessibilityHint("Double tap to select this model for local transcription")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            
            // Installed badge + Download button
            HStack {
                if downloadManager.getDownloadState(for: model.id) == .downloaded {
                    Text("Installed")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.semantic(.success).opacity(0.15))
                        .foregroundColor(.semantic(.success))
                        .cornerRadius(6)
                        .accessibilityLabel("Installed")
                }
                if downloadManager.getDownloadState(for: model.id) == .downloaded && !downloadManager.isLocalModelValid(model.id) {
                    Button(action: { downloadManager.repairModel(model.id) }) {
                        Label("Repair", systemImage: "wrench.and.screwdriver")
                    }
                    .buttonStyle(.bordered)
                    .tint(.semantic(.warning))
                    .accessibilityHint("Deletes and re-downloads the model")
                }
                Spacer()
                ModelDownloadButton(model: model, downloadManager: downloadManager)
            }
        }
    }
}

// MARK: - Performance Indicator

private struct PerformanceIndicator: View {
    let label: String
    let rating: WhisperModelInfo.ModelPerformance
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.semantic(.textSecondary))
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.semantic(.textSecondary))
            
            Text(rating.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(colorForRating(rating))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(rating.rawValue)")
    }
    
    private func colorForRating(_ rating: WhisperModelInfo.ModelPerformance) -> Color {
        switch rating {
        case .low: return .semantic(.warning)
        case .medium: return .semantic(.warning)
        case .high: return .semantic(.success)
        case .veryHigh: return .semantic(.brandPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    WhisperModelSelectionView()
}
