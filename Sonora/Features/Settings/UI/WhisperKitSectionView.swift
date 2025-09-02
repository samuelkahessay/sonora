import SwiftUI

struct WhisperKitSectionView: View {
    @State private var showingModelSelection = false
    
    private var selectedModel: WhisperModelInfo {
        UserDefaults.standard.selectedWhisperModelInfo
    }
    
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.semantic(.brandPrimary))
                        .font(.title3)
                    
                    Text("Local Transcription")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Local Transcription")
                .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Use offline AI models for private, local transcription without sending audio to external servers.")
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
                        Text("Local processing keeps your audio private and works offline, but may be slower than cloud transcription.")
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Information: Local processing keeps your audio private and works offline, but may be slower than cloud transcription.")
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .sheet(isPresented: $showingModelSelection) {
            WhisperModelSelectionView()
        }
    }
}

#Preview {
    WhisperKitSectionView()
        .padding()
}