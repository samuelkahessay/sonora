import SwiftUI

struct TierSectionView: View {
    let tier: ModelTier
    let models: [LocalModel]
    let isSupported: Bool
    let selectedModel: LocalModel
    
    let downloadManager: LocalModelDownloadManager
    let onModelSelect: (LocalModel) -> Void
    let onModelDownload: (LocalModel) -> Void
    let onModelDelete: (LocalModel) -> Void
    let onCancelDownload: (LocalModel) -> Void
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tier Header
            TierHeaderView(
                tier: tier,
                isSupported: isSupported,
                isExpanded: $isExpanded
            )
            
            // Models in this tier
            if isExpanded {
                LazyVStack(spacing: 8) {
                    ForEach(models, id: \.self) { model in
                        EnhancedModelRow(
                            model: model,
                            tier: tier,
                            isSelected: selectedModel == model,
                            isDownloaded: downloadManager.isModelReady(model),
                            isDownloading: downloadManager.isDownloading(model),
                            downloadProgress: downloadManager.downloadProgress(for: model),
                            isSupported: isSupported
                        ) {
                            onModelSelect(model)
                        } onDownload: {
                            onModelDownload(model)
                        } onDelete: {
                            onModelDelete(model)
                        } onCancelDownload: {
                            onCancelDownload(model)
                        }
                    }
                }
                .padding(.leading, 8)
            }
        }
    }
}

// MARK: - Tier Header

struct TierHeaderView: View {
    let tier: ModelTier
    let isSupported: Bool
    @Binding var isExpanded: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 12) {
                // Tier Icon
                Image(systemName: tier.systemImage)
                    .font(.title2)
                    .foregroundColor(isSupported ? .blue : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(tier.icon + " " + tier.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(isSupported ? .primary : .secondary)
                        
                        // Device Support Badge
                        if isSupported {
                            Text("✅ Compatible")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        } else {
                            Text("⚠️ Incompatible")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(tier.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Expand/Collapse Icon
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : 0))
                    .animation(.spring(response: 0.3), value: isExpanded)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Model Row

struct EnhancedModelRow: View {
    let model: LocalModel
    let tier: ModelTier
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Float
    let isSupported: Bool
    
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onCancelDownload: () -> Void
    
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                // Model Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(model.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(model.isDeviceCompatible ? .primary : .secondary)
                            
                            // Badges
                            BadgeRow(model: model, isSelected: isSelected, isDownloaded: isDownloaded)
                        }
                        
                        Text(model.useCaseDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Performance Indicators
                    PerformanceIndicators(model: model)
                }
                
                // Model Details
                ModelDetailsRow(model: model)
                
                // Incompatibility Warning
                if let reason = model.incompatibilityReason {
                    IncompatibilityWarning(reason: reason)
                }
                
                // Action Buttons
                ActionButtonsRow(
                    isDownloading: isDownloading,
                    isDownloaded: isDownloaded,
                    isSelected: isSelected,
                    downloadProgress: downloadProgress,
                    isCompatible: model.isDeviceCompatible,
                    onSelect: onSelect,
                    onDownload: onDownload,
                    onDelete: onDelete,
                    onCancelDownload: onCancelDownload
                )
            }
        }
        .opacity(model.isDeviceCompatible ? 1.0 : 0.7)
    }
}

// MARK: - Badge Row

struct BadgeRow: View {
    let model: LocalModel
    let isSelected: Bool
    let isDownloaded: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if model.isNew {
                Text("NEW")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            if isSelected && isDownloaded {
                Text("SELECTED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            if model == LocalModel.recommendedModel {
                Text("RECOMMENDED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Performance Indicators

struct PerformanceIndicators: View {
    let model: LocalModel
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 2) {
                Text("Speed:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                ForEach(0..<5) { index in
                    Image(systemName: index < model.speedRating ? "bolt.fill" : "bolt")
                        .font(.caption2)
                        .foregroundColor(index < model.speedRating ? .orange : .secondary)
                }
            }
            
            HStack(spacing: 2) {
                Text("Quality:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                ForEach(0..<5) { index in
                    Image(systemName: index < model.qualityRating ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundColor(index < model.qualityRating ? .yellow : .secondary)
                }
            }
        }
    }
}

// MARK: - Model Details Row

struct ModelDetailsRow: View {
    let model: LocalModel
    
    var body: some View {
        HStack {
            Label(model.approximateSize, systemImage: "internaldrive")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(Int(model.minRAMRequired / 1_000_000_000))GB RAM")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Incompatibility Warning

struct IncompatibilityWarning: View {
    let reason: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.orange)
            
            Text(reason)
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Action Buttons Row

struct ActionButtonsRow: View {
    let isDownloading: Bool
    let isDownloaded: Bool
    let isSelected: Bool
    let downloadProgress: Float
    let isCompatible: Bool
    
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onCancelDownload: () -> Void
    
    var body: some View {
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
                        .font(.caption)
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
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isCompatible)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            TierSectionView(
                tier: .fast,
                models: LocalModel.modelsForTier(.fast),
                isSupported: true,
                selectedModel: .phi4_mini,
                downloadManager: LocalModelDownloadManager.shared,
                onModelSelect: { _ in },
                onModelDownload: { _ in },
                onModelDelete: { _ in },
                onCancelDownload: { _ in }
            )
        }
        .padding()
    }
}