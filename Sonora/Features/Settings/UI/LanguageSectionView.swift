import SwiftUI

struct LanguageSectionView: View {
    @State private var selectedCode: String = UserDefaults.standard.string(forKey: "preferredTranscriptionLanguage") ?? "auto"

    private let languages: [(code: String, name: String)] = [
        ("auto", "Auto (Detect)"),
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("hi", "Hindi")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
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
            .onChange(of: selectedCode) { newValue in
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
        .padding()
        .background(Color.semantic(.bgSecondary))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.semantic(.separator).opacity(0.45), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

#Preview {
    LanguageSectionView()
        .padding()
}

