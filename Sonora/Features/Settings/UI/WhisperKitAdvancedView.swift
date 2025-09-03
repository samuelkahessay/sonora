import SwiftUI

struct WhisperKitAdvancedView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var backgroundDownloads = AppConfiguration.shared.whisperBackgroundDownloads
    @State private var releaseAfter = AppConfiguration.shared.releaseLocalModelAfterTranscription
    @State private var wordTimestamps = AppConfiguration.shared.whisperWordTimestamps
    @State private var chunking = AppConfiguration.shared.whisperChunkingStrategy // "vad" or "none"

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Downloads")) {
                    Toggle("Background model downloads", isOn: $backgroundDownloads)
                        .onChange(of: backgroundDownloads) { _, newValue in
                            AppConfiguration.shared.whisperBackgroundDownloads = newValue
                        }
                    Text("Uses a background URLSession when supported to continue downloading if the app is backgrounded.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
                Section(header: Text("Memory")) {
                    Toggle("Release model after transcription", isOn: $releaseAfter)
                        .onChange(of: releaseAfter) { _, newValue in
                            AppConfiguration.shared.releaseLocalModelAfterTranscription = newValue
                        }
                    Text("Unloads the model after each transcription to save memory on older devices. Enables slower subsequent inits.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
                Section(header: Text("Decoding Options")) {
                    Toggle("Word timestamps", isOn: $wordTimestamps)
                        .onChange(of: wordTimestamps) { _, newValue in
                            AppConfiguration.shared.whisperWordTimestamps = newValue
                        }
                    Picker("Chunking", selection: Binding(
                        get: { chunking }, set: { chunking = $0; AppConfiguration.shared.whisperChunkingStrategy = $0 }
                    )) {
                        Text("VAD").tag("vad")
                        Text("None").tag("none")
                    }
                    .pickerStyle(.segmented)
                    Text("VAD splits audio by voice activity for efficiency. None sends full audio.")
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                }
                Section(header: Text("HF Cache")) {
                    Text(hfHomePath)
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("WhisperKit Advanced")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var hfHomePath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("huggingface", isDirectory: true).path
    }
}

#Preview {
    WhisperKitAdvancedView()
}
