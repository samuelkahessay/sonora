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

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Choose your spoken language to improve accuracy. Auto will detect language automatically.")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.textSecondary))
            }

            Picker("Language", selection: $selectedCode) {
                ForEach(languages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedCode) { _, newValue in
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
                Text("You can change this any time. Non-English results show a banner warning by default.")
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
            }
        }
    }
}

#Preview {
    LanguageSectionView()
        .padding()
}
