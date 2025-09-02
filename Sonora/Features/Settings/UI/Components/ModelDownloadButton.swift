import SwiftUI

/// Download button component for WhisperKit models
struct ModelDownloadButton: View {
    let model: WhisperModelInfo
    @ObservedObject var downloadManager: ModelDownloadManager
    
    private var downloadState: ModelDownloadState {
        downloadManager.getDownloadState(for: model.id)
    }
    
    private var downloadProgress: Double {
        downloadManager.getDownloadProgress(for: model.id)
    }
    
    private var downloadError: String? {
        downloadManager.getDownloadError(for: model.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            mainButton
            
            if downloadState == .downloading {
                downloadProgressView
            }
            
            if let error = downloadError, downloadState == .failed {
                errorView(error: error)
            }
        }
    }
    
    // MARK: - Main Button
    
    @ViewBuilder
    private var mainButton: some View {
        HStack(spacing: Spacing.sm) {
                buttonIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(buttonTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(buttonTitleColor)
                    
                    if downloadState == .downloading {
                        Text("\(Int(downloadProgress * 100))% complete")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                    } else if downloadState == .stale {
                        Text("Stuck - tap to refresh")
                            .font(.caption)
                            .foregroundColor(.semantic(.error))
                    }
                }
                
                Spacer()
                
                if downloadState == .downloading {
                    Button(action: { downloadManager.cancelDownload(for: model.id) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.semantic(.error))
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel download")
                } else if downloadState == .stale {
                    Button(action: { downloadManager.checkDownloadHealth() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.semantic(.textSecondary))
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Check status")
                }
        }
        .padding(Spacing.md)
        .background(buttonBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(buttonBorderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleButtonAction()
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    // MARK: - Progress View
    
    @ViewBuilder
    private var downloadProgressView: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Downloading...")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                
                Spacer()
                
                Text("\(Int(downloadProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.semantic(.brandPrimary))
            }
            
            ProgressView(value: downloadProgress)
                .tint(.semantic(.brandPrimary))
                .background(.secondary.opacity(0.2))
                .accessibilityValue("Progress: \(Int(downloadProgress * 100)) percent")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Download progress: \(Int(downloadProgress * 100)) percent complete")
    }
    
    // MARK: - Error View
    
    @ViewBuilder
    private func errorView(error: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.semantic(.error))
                .font(.caption)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.semantic(.error))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Download error: \(error)")
    }
    
    // MARK: - Button Properties
    
    private var buttonIcon: some View {
        Image(systemName: buttonIconName)
            .foregroundColor(buttonIconColor)
            .font(.title3)
            .frame(width: 24, height: 24)
    }
    
    private var buttonIconName: String {
        switch downloadState {
        case .notDownloaded: return "arrow.down.circle"
        case .downloading: return "arrow.down.circle.fill"
        case .downloaded: return "checkmark.circle.fill"
        case .failed: return "arrow.clockwise.circle"
        case .stale: return "exclamationmark.triangle.circle"
        }
    }
    
    private var buttonIconColor: Color {
        switch downloadState {
        case .notDownloaded: return .semantic(.brandPrimary)
        case .downloading: return .semantic(.brandPrimary)
        case .downloaded: return .semantic(.success)
        case .failed: return .semantic(.warning)
        case .stale: return .semantic(.error)
        }
    }
    
    private var buttonTitle: String {
        switch downloadState {
        case .notDownloaded: return "Download Model"
        case .downloading: return "Downloading..."
        case .downloaded: return "Downloaded"
        case .failed: return "Retry Download"
        case .stale: return "Force Retry"
        }
    }
    
    private var buttonTitleColor: Color {
        switch downloadState {
        case .notDownloaded: return .semantic(.brandPrimary)
        case .downloading: return .semantic(.brandPrimary)
        case .downloaded: return .semantic(.success)
        case .failed: return .semantic(.warning)
        case .stale: return .semantic(.error)
        }
    }
    
    private var buttonBackground: Color {
        switch downloadState {
        case .notDownloaded: return .semantic(.brandPrimary).opacity(0.1)
        case .downloading: return .semantic(.brandPrimary).opacity(0.1)
        case .downloaded: return .semantic(.success).opacity(0.1)
        case .failed: return .semantic(.warning).opacity(0.1)
        case .stale: return .semantic(.error).opacity(0.1)
        }
    }
    
    private var buttonBorderColor: Color {
        switch downloadState {
        case .notDownloaded: return .semantic(.brandPrimary).opacity(0.3)
        case .downloading: return .semantic(.brandPrimary).opacity(0.3)
        case .downloaded: return .semantic(.success).opacity(0.3)
        case .failed: return .semantic(.warning).opacity(0.3)
        case .stale: return .semantic(.error).opacity(0.3)
        }
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        switch downloadState {
        case .notDownloaded: return "Download \(model.displayName) model"
        case .downloading: return "Downloading \(model.displayName) model, \(Int(downloadProgress * 100)) percent complete"
        case .downloaded: return "\(model.displayName) model downloaded"
        case .failed: return "Retry downloading \(model.displayName) model"
        case .stale: return "Force retry downloading \(model.displayName) model"
        }
    }
    
    private var accessibilityHint: String {
        switch downloadState {
        case .notDownloaded: return "Double tap to start downloading this model"
        case .downloading: return "Download in progress"
        case .downloaded: return "Model is ready for use"
        case .failed: return "Double tap to retry the download"
        case .stale: return "Double tap to force retry and clear cached state"
        }
    }
    
    // MARK: - Actions
    
    private func handleButtonAction() {
        HapticManager.shared.playSelection()
        
        switch downloadState {
        case .notDownloaded:
            downloadManager.downloadModel(model.id)
        case .downloading:
            // No action - button is disabled
            break
        case .downloaded:
            // Could show options like delete, but for now no action
            break
        case .failed:
            downloadManager.retryDownload(for: model.id)
        case .stale:
            downloadManager.forceRetryDownload(for: model.id)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Preview different states
        ModelDownloadButton(
            model: WhisperModelInfo.availableModels[0],
            downloadManager: ModelDownloadManager(provider: WhisperKitModelProvider())
        )
        
        ModelDownloadButton(
            model: WhisperModelInfo.availableModels[1], 
            downloadManager: ModelDownloadManager(provider: WhisperKitModelProvider())
        )
    }
    .padding()
}
