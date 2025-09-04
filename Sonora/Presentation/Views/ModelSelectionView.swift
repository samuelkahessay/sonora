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
                // Header
                HeaderSection()
                
                // Device capability info
                DeviceCapabilityCard()
                
                // Tier-based model sections
                LazyVStack(spacing: 16) {
                    ForEach(ModelTier.allCases, id: \.self) { tier in
                        TierSectionView(
                            tier: tier,
                            models: LocalModel.modelsForTier(tier),
                            isSupported: UIDevice.current.supportsTier(tier),
                            selectedModel: selectedModel,
                            downloadManager: downloadManager,
                            onModelSelect: selectModel,
                            onModelDownload: { downloadManager.downloadModel($0) },
                            onModelDelete: { downloadManager.deleteModel($0) },
                            onCancelDownload: { downloadManager.cancelDownload(for: $0) }
                        )
                    }
                }
                
                // Storage and recommendations
                VStack(spacing: 12) {
                    StorageInfoCard(downloadManager: downloadManager)
                    RecommendationCard()
                }
                
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

// MARK: - Header Section

struct HeaderSection: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("AI Model Selection")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose the best model for your device and use case")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
}

// MARK: - Device Capability Card

struct DeviceCapabilityCard: View {
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device: \(UIDevice.current.readableModelName)")
                            .font(.headline)
                        
                        Text("RAM: \(formatMemory(UIDevice.current.estimatedRAMCapacity))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Tier badge
                    Text(UIDevice.current.deviceTier.icon)
                        .font(.title)
                }
                
                // Supported tiers
                HStack(spacing: 8) {
                    Text("Supported Tiers:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(UIDevice.current.supportedTiers, id: \.self) { tier in
                        Text(tier.icon + " " + tier.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    private func formatMemory(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.0fGB", gb)
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                    
                    Text("Recommendation")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                let recommendedModel = LocalModel.recommendedModel
                
                Text("For your \(UIDevice.current.readableModelName), we recommend \(recommendedModel.displayName) for the best balance of speed and quality.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(recommendedModel.useCaseDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
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
