import SwiftUI

struct ModelDownloadView: View {
    @StateObject private var appConfig = AppConfiguration.shared
    @StateObject private var downloadManager = LocalModelDownloadManager.shared
    
    private var selectedModel: LocalModel {
        LocalModel(rawValue: appConfig.selectedLocalModel) ?? LocalModel.defaultModel
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Current model info
            VStack(spacing: 16) {
                Image(systemName: "cpu")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Local AI Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Voice memos are analyzed on your device using local AI models")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Current model status
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Current Model")
                            .font(.headline)
                        
                        Spacer()
                        
                        if downloadManager.isModelReady(selectedModel) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedModel.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(selectedModel.approximateSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if downloadManager.isModelReady(selectedModel) {
                            Text("Ready")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Not Downloaded")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            // Device compatibility info
            SettingsCard {
                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device: \(UIDevice.current.readableModelName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if UIDevice.current.isProModel {
                            Text("All models supported")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Large models not supported")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            // Action buttons
            VStack(spacing: 12) {
                NavigationLink(destination: ModelSelectionView()) {
                    Label("Manage Models", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                if !downloadManager.isModelReady(selectedModel) {
                    Button(action: {
                        downloadManager.downloadModel(selectedModel)
                    }) {
                        Label("Download \(selectedModel.displayName)", systemImage: "arrow.down.circle.fill")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!selectedModel.isDeviceCompatible || downloadManager.isDownloading(selectedModel))
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Local AI Model")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            downloadManager.refreshModelStatus()
        }
    }
}
