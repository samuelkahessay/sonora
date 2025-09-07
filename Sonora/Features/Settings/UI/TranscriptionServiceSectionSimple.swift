import SwiftUI

/// Simplified transcription service section for beta submission.
struct TranscriptionServiceSectionSimple: View {
    @StateObject private var appConfig = AppConfiguration.shared
    @StateObject private var downloadManager = DIContainer.shared.modelDownloadManager()

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.semantic(.brandPrimary))
                        .font(.title3)
                    Text("Transcription Service")
                        .font(SonoraDesignSystem.Typography.headingSmall)
                        .fontWeight(.semibold)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Transcription Service")
                .accessibilityAddTraits(.isHeader)

                Toggle("Use Local Transcription", isOn: Binding(
                    get: { UserDefaults.standard.selectedTranscriptionService == .localWhisperKit },
                    set: { isOn in
                        let target: TranscriptionServiceType = isOn ? .localWhisperKit : .cloudAPI
                        HapticManager.shared.playSelection()
                        UserDefaults.standard.selectedTranscriptionService = target
                        AppConfiguration.shared.strictLocalWhisper = (target == .localWhisperKit)
                        Logger.shared.info("Selected transcription service (simplified): \(target.displayName)")
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .semantic(.brandPrimary)))
                .accessibilityLabel("Toggle local transcription")

                if UserDefaults.standard.selectedTranscriptionService == .localWhisperKit {
                    Text("On-device model (downloaded as needed). Works offline.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                } else {
                    Text("Cloud API – faster, requires internet.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
            }
        }
    }
}

#Preview {
    TranscriptionServiceSectionSimple()
        .padding()
}

