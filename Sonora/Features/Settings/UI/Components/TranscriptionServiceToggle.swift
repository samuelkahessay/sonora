import SwiftUI

/// Toggle component for selecting transcription service (Cloud API vs Local WhisperKit)
struct TranscriptionServiceToggle: View {
    @ObservedObject var downloadManager: ModelDownloadManager
    @State private var selectedService: TranscriptionServiceType = UserDefaults.standard.selectedTranscriptionService
    
    private var isLocalServiceAvailable: Bool {
        UserDefaults.standard.isSelectedTranscriptionServiceAvailable(downloadManager: downloadManager)
    }
    
    private var selectedModel: WhisperModelInfo {
        UserDefaults.standard.selectedWhisperModelInfo
    }
    
    private var selectedModelDownloadState: ModelDownloadState {
        downloadManager.getDownloadState(for: selectedModel.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            headerSection
            toggleSection
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.semantic(.brandPrimary))
                .font(.title3)
            
            Text("Transcription Service")
                .font(.headline)
                .fontWeight(.semibold)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Transcription Service")
        .accessibilityAddTraits(.isHeader)
    }
    
    // MARK: - Toggle Section
    
    @ViewBuilder
    private var toggleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Choose your preferred transcription method:")
                .font(.subheadline)
                .foregroundColor(.semantic(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(spacing: Spacing.sm) {
                ForEach(TranscriptionServiceType.allCases, id: \.self) { service in
                    ServiceOptionRow(
                        service: service,
                        isSelected: selectedService == service,
                        isEnabled: isServiceEnabled(service),
                        onSelect: {
                            selectService(service)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Unavailable Local Service Section
    
    @ViewBuilder
    private var unavailableLocalServiceSection: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "info.circle")
                .foregroundColor(.semantic(.warning))
                .font(.caption)
            
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Local transcription temporarily unavailable")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.semantic(.warning))
                
                Text(localServiceUnavailableMessage)
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .background(Color.semantic(.warning).opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: Local transcription unavailable. \(localServiceUnavailableMessage)")
    }
    
    // MARK: - Helper Properties
    
    private var localServiceUnavailableMessage: String {
        switch selectedModelDownloadState {
        case .notDownloaded:
            return "Download the \(selectedModel.displayName) model to enable local transcription. Falling back to Cloud API."
        case .downloading:
            return "The \(selectedModel.displayName) model is currently downloading. Falling back to Cloud API until download completes."
        case .failed:
            return "Failed to download the \(selectedModel.displayName) model. Falling back to Cloud API."
        case .downloaded:
            // This shouldn't happen if isLocalServiceAvailable is working correctly
            return "Local model is downloaded but not available. Please try selecting a different model."
        case .stale:
            return "Download of the \(selectedModel.displayName) model appears stuck. Falling back to Cloud API."
        }
    }
    
    // MARK: - Helper Methods
    
    private func isServiceEnabled(_ service: TranscriptionServiceType) -> Bool {
        true
    }
    
    private func selectService(_ service: TranscriptionServiceType) {
        guard isServiceEnabled(service) else { return }
        
        HapticManager.shared.playSelection()
        selectedService = service
        UserDefaults.standard.selectedTranscriptionService = service
        // Enforce strict-local behavior automatically to avoid cloud costs when local is chosen
        AppConfiguration.shared.strictLocalWhisper = (service == .localWhisperKit)
        
        Logger.shared.info("Selected transcription service: \(service.displayName)")
    }
}

// MARK: - Service Option Row

private struct ServiceOptionRow: View {
    let service: TranscriptionServiceType
    let isSelected: Bool
    let isEnabled: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                Image(systemName: service.icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(titleColor)
                    
                    Text(service.description)
                        .font(.caption)
                        .foregroundColor(descriptionColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Selection indicator
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
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(service.displayName): \(service.description)")
        .accessibilityHint(isEnabled ? "Double tap to select this transcription service" : "Not available")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    
    // MARK: - Style Properties
    
    private var iconColor: Color {
        if !isEnabled {
            return .semantic(.textSecondary)
        }
        return isSelected ? .semantic(.brandPrimary) : .semantic(.textPrimary)
    }
    
    private var titleColor: Color {
        if !isEnabled {
            return .semantic(.textSecondary)
        }
        return .semantic(.textPrimary)
    }
    
    private var descriptionColor: Color {
        return .semantic(.textSecondary)
    }
    
    private var backgroundColor: Color {
        if isSelected && isEnabled {
            return .semantic(.brandPrimary).opacity(0.1)
        }
        return .semantic(.fillSecondary)
    }
    
    private var borderColor: Color {
        if isSelected && isEnabled {
            return .semantic(.brandPrimary).opacity(0.3)
        }
        return .semantic(.separator).opacity(0.2)
    }
}

#Preview {
    TranscriptionServiceToggle(downloadManager: ModelDownloadManager(provider: WhisperKitModelProvider()))
        .padding()
}
