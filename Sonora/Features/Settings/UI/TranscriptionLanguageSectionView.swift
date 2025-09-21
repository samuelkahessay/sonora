import SwiftUI

struct TranscriptionLanguageSectionView: View {
    @StateObject private var viewModel = TranscriptionLanguageSettingsViewModel()

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Transcription Language", systemImage: "globe")
                    .font(SonoraDesignSystem.Typography.headingSmall)
                    .accessibilityAddTraits(.isHeader)

                Text("Choose the language to send with cloud Whisper transcriptions. This helps improve accuracy and keeps the output in the right language.")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))

                Picker("Language", selection: $viewModel.selectedLanguageCode) {
                    ForEach(viewModel.languageOptions) { option in
                        Text(option.displayName)
                            .tag(option.code)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Preferred transcription language")
            }
        }
        .onChange(of: viewModel.selectedLanguageCode) { _, newValue in
            viewModel.updateSelectedLanguage(to: newValue)
        }
    }
}

#Preview {
    TranscriptionLanguageSectionView()
}
