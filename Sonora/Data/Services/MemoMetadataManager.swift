import Foundation

class MemoMetadataManager {
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    private func metadataURL(for audioURL: URL) -> URL {
        let filename = audioURL.deletingPathExtension().lastPathComponent + "_metadata.json"
        return documentsPath.appendingPathComponent(filename)
    }
    
    func getTranscriptionState(for audioURL: URL) -> TranscriptionState {
        let metadataURL = metadataURL(for: audioURL)
        
        guard FileManager.default.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(MemoMetadata.self, from: data) else {
            return .notStarted
        }
        
        return metadata.transcriptionState
    }
    
    func saveTranscriptionState(_ state: TranscriptionState, for audioURL: URL) {
        let metadataURL = metadataURL(for: audioURL)
        let metadata = MemoMetadata(transcriptionState: state)
        
        do {
            let data = try JSONEncoder().encode(metadata)
            try data.write(to: metadataURL)
        } catch {
            print("Failed to save transcription state: \(error)")
        }
    }
    
    func deleteMetadata(for audioURL: URL) {
        let metadataURL = metadataURL(for: audioURL)
        try? FileManager.default.removeItem(at: metadataURL)
    }
    
    func loadMetadata (for audioURL: URL) -> [String: Any] {
        let url = metadataURL(for: audioURL)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }
    
    /// Merge and persist arbitrary metadata keys/values into the sidecar JSON.
    /// Values should be JSON-serializable (String/Number/Bool/Array/Dictionary/NSNull).
    func upsertMetadata(for audioURL: URL, changes: [String: Any]) {
        let url = metadataURL(for: audioURL)

        var merged = loadMetadata(for: audioURL)
        for (k, v) in changes {
            merged[k] = v
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted])
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Failed to upsert metadata: \(error)")
        }
    }
}

struct MemoMetadata: Codable {
    let transcriptionState: TranscriptionState
}
