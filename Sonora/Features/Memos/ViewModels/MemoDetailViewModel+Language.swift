import Foundation

// MARK: - Language Banner API (moved)
extension MemoDetailViewModel {
    func updateLanguageDetection(language: String?, qualityScore: Double) {
        detectedLanguage = language
        guard let memo = currentMemo else { return }
        if languageBannerDismissedForMemo[memo.id] == true {
            showNonEnglishBanner = false
            return
        }

        // If user explicitly set a preferred language, don't warn when it matches
        if let pref = AppConfiguration.shared.preferredTranscriptionLanguage, let lang = language?.lowercased() {
            if pref == lang { showNonEnglishBanner = false; return }
        }

        if let lang = language, lang.lowercased() != "en", qualityScore > 0.6, AppConfiguration.shared.preferredTranscriptionLanguage == nil {
            showNonEnglishBanner = true
            languageBannerMessage = formatLanguageBannerMessage(for: lang)
        } else {
            showNonEnglishBanner = false
        }
    }

    fileprivate func formatLanguageBannerMessage(for languageCode: String) -> String {
        let languageName = WhisperLanguages.localizedDisplayName(for: languageCode)
        return "Detected language: \(languageName). Result may be less accurate."
    }

    func dismissLanguageBanner() {
        showNonEnglishBanner = false
        if let memo = currentMemo { languageBannerDismissedForMemo[memo.id] = true }
    }
}

