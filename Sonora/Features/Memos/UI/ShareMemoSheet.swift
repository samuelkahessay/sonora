//
//  ShareMemoSheet.swift
//  Sonora
//
//  Advanced share sheet with toggle options for memo content
//

import SwiftUI
import Foundation

struct ShareMemoSheet: View {
    let memo: Memo
    @ObservedObject var viewModel: MemoDetailViewModel
    let dismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Share Memo")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose what to include in your share")
                        .font(.subheadline)
                        .foregroundColor(.semantic(.textSecondary))
                }
                
                // Content Options
                VStack(spacing: 16) {
                    // Audio File Toggle
                    ShareOptionRow(
                        title: "Voice Recording",
                        subtitle: "Audio file (\(memo.durationString))",
                        icon: "waveform",
                        isEnabled: $viewModel.shareAudioEnabled,
                        isAvailable: true
                    )
                    
                    // Transcription Toggle
                    ShareOptionRow(
                        title: "Transcription",
                        subtitle: transcriptionSubtitle,
                        icon: "doc.text",
                        isEnabled: $viewModel.shareTranscriptionEnabled,
                        isAvailable: viewModel.isTranscriptionCompleted
                    )
                    
                    // Analysis Toggle
                    ShareOptionRow(
                        title: "AI Analysis",
                        subtitle: analysisSubtitle,
                        icon: "brain",
                        isEnabled: $viewModel.shareAnalysisEnabled,
                        isAvailable: hasAnalysisResults
                    )
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    if viewModel.isPreparingShare {
                        ProgressView("Preparing share...")
                            .frame(maxWidth: .infinity)
                    }
                    Button(viewModel.isPreparingShare ? "Preparing..." : "Share Selected Content") {
                        HapticManager.shared.playSelection()
                        Task {
                            await viewModel.shareSelectedContent()
                            // Dismiss the sheet; onDismiss will present the system share UI
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasSelectedContent || viewModel.isPreparingShare)
                    .frame(maxWidth: .infinity)
                    
                    Button("Cancel") {
                        HapticManager.shared.playLightImpact()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isPreparingShare)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - Helper Properties
    
    private var transcriptionSubtitle: String {
        if viewModel.isTranscriptionCompleted {
            if let text = viewModel.transcriptionText {
                let wordCount = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                return "\(wordCount) words"
            }
            return "Text available"
        }
        return "Not available"
    }
    
    private var analysisSubtitle: String {
        if hasAnalysisResults {
            if let updated = viewModel.latestAnalysisUpdatedAt {
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = .short
                return "Updated: \(df.string(from: updated))"
            }
            return "Available"
        }
        return "Not available"
    }

    
    private var hasAnalysisResults: Bool {
        viewModel.hasAnalysisAvailable
    }
    
    private var hasSelectedContent: Bool {
        viewModel.shareAudioEnabled || viewModel.shareTranscriptionEnabled || viewModel.shareAnalysisEnabled
    }
    
    // MARK: - Setup
    
    private func setupInitialState() {
        // Smart defaults
        viewModel.shareAudioEnabled = true
        viewModel.shareTranscriptionEnabled = viewModel.isTranscriptionCompleted
        viewModel.shareAnalysisEnabled = hasAnalysisResults
    }
}

// MARK: - Share Option Row Component

struct ShareOptionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isEnabled: Bool
    let isAvailable: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(textColor)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { isAvailable && isEnabled },
                set: { newValue in
                    if isAvailable {
                        HapticManager.shared.playLightImpact()
                        isEnabled = newValue
                    }
                }
            ))
            .disabled(!isAvailable)
            .labelsHidden()
        }
        .padding(.vertical, 8)
        .opacity(isAvailable ? 1.0 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
        .accessibilityHint(isAvailable ? "Toggle to include in share" : "Not available")
    }
    
    private var iconColor: Color {
        if !isAvailable {
            return .semantic(.textSecondary)
        }
        return isEnabled ? .semantic(.brandPrimary) : .semantic(.textSecondary)
    }
    
    private var textColor: Color {
        isAvailable ? .semantic(.textPrimary) : .semantic(.textSecondary)
    }
}

#Preview {
    ShareMemoSheet(
        memo: Memo(
            filename: "test.m4a",
            fileURL: URL(fileURLWithPath: "/test.m4a"),
            creationDate: Date()
        ),
        viewModel: DIContainer.shared.viewModelFactory().createMemoDetailViewModel()
    ) {
        // Dismiss action for preview
    }
}
