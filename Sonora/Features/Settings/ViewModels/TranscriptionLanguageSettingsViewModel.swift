import Foundation

@MainActor
final class TranscriptionLanguageSettingsViewModel: ObservableObject {
    struct LanguageOption: Identifiable, Equatable {
        let code: String
        let displayName: String

        var id: String { code }
    }

    @Published var selectedLanguageCode: String
    let languageOptions: [LanguageOption]

    private let configuration: AppConfiguration

    init(configuration: AppConfiguration = .shared) {
        self.configuration = configuration

        // Sort languages by localized display name for a friendlier menu ordering
        let sortedCodes = WhisperLanguages.codeToName.keys.sorted { lhs, rhs in
            WhisperLanguages.localizedDisplayName(for: lhs) < WhisperLanguages.localizedDisplayName(for: rhs)
        }
        self.languageOptions = sortedCodes.map { code in
            LanguageOption(code: code, displayName: WhisperLanguages.localizedDisplayName(for: code))
        }

        if let stored = configuration.preferredTranscriptionLanguage,
           !stored.isEmpty,
           languageOptions.contains(where: { $0.code == stored }) {
            self.selectedLanguageCode = stored
        } else {
            // Default to English and persist so the server receives a language hint automatically
            self.selectedLanguageCode = "en"
            configuration.setPreferredTranscriptionLanguage("en")
        }
    }

    func updateSelectedLanguage(to code: String) {
        guard languageOptions.contains(where: { $0.code == code }) else { return }
        configuration.setPreferredTranscriptionLanguage(code)
    }
}
