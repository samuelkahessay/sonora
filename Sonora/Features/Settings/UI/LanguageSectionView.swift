import SwiftUI

struct LanguageSectionView: View {
    @State private var selectedCode: String = UserDefaults.standard.string(forKey: "preferredTranscriptionLanguage") ?? "auto"
    private var languages: [(code: String, name: String)] {
        var items = WhisperLanguages.pickerItems()
        items.insert(("auto", "Auto (Detect)"), at: 0)
        return items
    }

    var body: some View {
        SettingsCard {
            Text("Transcription Language")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Choose your spoken language to improve accuracy. Auto will detect language automatically.")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
                    .accessibilityLabel("Choose your spoken language to improve transcription accuracy. Auto detect will automatically identify the language.")
            }

            Picker("Language", selection: $selectedCode) {
                ForEach(languages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Transcription language selection")
            .accessibilityHint("Double tap to choose your preferred language for voice transcription")
            .accessibilityValue(getCurrentLanguageName())
            .onChange(of: selectedCode) { _, newValue in
                HapticManager.shared.playSelection()
                let code = newValue == "auto" ? nil : newValue
                AppConfiguration.shared.setPreferredTranscriptionLanguage(code)
            }
            .onAppear {
                // Sync with current configuration value
                if let pref = AppConfiguration.shared.preferredTranscriptionLanguage {
                    selectedCode = pref
                } else {
                    selectedCode = "auto"
                }
            }

            HStack(spacing: Spacing.md) {
                Image(systemName: "info.circle")
                    .foregroundColor(.semantic(.textSecondary))
                    .accessibilityHidden(true)
                Text("You can change this any time. Non-English results show a banner warning by default.")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Information: You can change the language setting any time. Non-English transcription results will show a banner warning by default.")
            .accessibilityAddTraits(.isStaticText)
        }
    }
    
    private func getCurrentLanguageName() -> String {
        return languages.first { $0.code == selectedCode }?.name ?? "Auto (Detect)"
    }
}

#Preview {
    LanguageSectionView()
        .padding()
}
