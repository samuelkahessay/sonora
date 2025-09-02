import SwiftUI

struct WhisperModelSelectionView: View {
    @State private var selectedModelId: String = UserDefaults.standard.selectedWhisperModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    headerSection
                    modelListSection
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
                    ForEach(WhisperModelInfo.availableModels, id: \.id) { model in
                        ModelRowView(
                            model: model,
                            isSelected: selectedModelId == model.id
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
}

// MARK: - Model Row View

private struct ModelRowView: View {
    let model: WhisperModelInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
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
