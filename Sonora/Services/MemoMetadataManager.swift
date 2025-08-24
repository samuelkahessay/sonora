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
}

struct MemoMetadata: Codable {
    let transcriptionState: TranscriptionState
}