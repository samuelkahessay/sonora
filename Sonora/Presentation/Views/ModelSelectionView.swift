import SwiftUI

struct ModelSelectionView: View {
    @StateObject private var downloadManager = LocalModelDownloadManager.shared
    @StateObject private var appConfig = AppConfiguration.shared
    
    @State private var selectedModel: LocalModel
    
    init() {
        let currentModel = LocalModel(rawValue: AppConfiguration.shared.selectedLocalModel) ?? LocalModel.defaultModel
        _selectedModel = State(initialValue: currentModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current selection header
                VStack(spacing: 8) {
                    Text("Select Local AI Model")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choose which model to use for voice memo analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Device info
                DeviceInfoCard()
                
                // Model list
                LazyVStack(spacing: 12) {
                    ForEach(LocalModel.allCases, id: \.self) { model in
                        ModelRow(
                            model: model,
                            isSelected: selectedModel == model,
                            isDownloaded: downloadManager.isModelReady(model),
                            isDownloading: downloadManager.isDownloading(model),
                            downloadProgress: downloadManager.downloadProgress(for: model)
                        ) {
                            selectModel(model)
                        } onDownload: {
                            downloadManager.downloadModel(model)
                        } onDelete: {
                            downloadManager.deleteModel(model)
                        } onCancelDownload: {
                            downloadManager.cancelDownload(for: model)
                        }
                    }
                }
                
                // Storage info
                StorageInfoCard(downloadManager: downloadManager)
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal)
        }
        .navigationTitle("AI Models")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            downloadManager.refreshModelStatus()
        }
    }
    
    private func selectModel(_ model: LocalModel) {
        guard downloadManager.isModelReady(model) else { return }
        
        selectedModel = model
        appConfig.selectedLocalModel = model.rawValue
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Device Info Card

struct DeviceInfoCard: View {
    var body: some View {
        SettingsCard {
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device: \(UIDevice.current.readableModelName)")
                        .font(.headline)
                    
                    Text("RAM: \(formatMemory(UIDevice.current.estimatedRAMCapacity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if UIDevice.current.isProModel {
                        Text("Pro Model - All models supported")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Standard Model - Large models not supported")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func formatMemory(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.0fGB", gb)
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: LocalModel
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Float
    
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onCancelDownload: () -> Void
    
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(model.displayName)
                                .font(.headline)
                                .foregroundColor(model.isDeviceCompatible ? .primary : .secondary)
                            
                            if isSelected && isDownloaded {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Text(model.approximateSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Compatibility indicator
                    if !model.isDeviceCompatible {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }
                
                // Incompatibility warning
                if let reason = model.incompatibilityReason {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // Download/Status section
                if isDownloading {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ProgressView(value: downloadProgress)
                                .progressViewStyle(.linear)
                            
                            Text("\(Int(downloadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Cancel") {
                            onCancelDownload()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                } else if isDownloaded {
                    HStack(spacing: 12) {
                        Button(action: onSelect) {
                            Text(isSelected ? "Selected" : "Select")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSelected)
                        
                        Button("Delete") {
                            onDelete()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                } else {
                    Button(action: onDownload) {
                        Label("Download", systemImage: "arrow.down.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.isDeviceCompatible)
                }
            }
        }
        .opacity(model.isDeviceCompatible ? 1.0 : 0.7)
    }
}

// MARK: - Storage Info Card

struct StorageInfoCard: View {
    let downloadManager: LocalModelDownloadManager
    
    var body: some View {
        SettingsCard {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage Used")
                        .font(.headline)
                    
                    Text("\(downloadManager.formatFileSize(downloadManager.getTotalDiskSpaceUsed()))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationView {
        ModelSelectionView()
    }
}
