import Foundation
import Combine

@MainActor
final class TranscriptionRepositoryImpl: ObservableObject, TranscriptionRepository {
    @Published var transcriptionStates: [String: TranscriptionState] = [:]
    
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let metadataManager = MemoMetadataManager()
    
    private func transcriptionURL(for memoId: UUID) -> URL {
        let filename = "\(memoId.uuidString)_transcription.json"
        return documentsPath.appendingPathComponent("transcriptions").appendingPathComponent(filename)
    }
    
    private func ensureTranscriptionDirectory() {
        let transcriptionDir = documentsPath.appendingPathComponent("transcriptions")
        if !FileManager.default.fileExists(atPath: transcriptionDir.path) {
            try? FileManager.default.createDirectory(at: transcriptionDir, withIntermediateDirectories: true)
        }
    }

    private func metadataURL(for memoId: UUID) -> URL {
        let dir = documentsPath.appendingPathComponent("transcriptions").appendingPathComponent("meta", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("\(memoId.uuidString).json")
    }
    
    private func memoIdKey(for memoId: UUID) -> String {
        return memoId.uuidString
    }
    
    func saveTranscriptionState(_ state: TranscriptionState, for memoId: UUID) {
        let key = memoIdKey(for: memoId)
        transcriptionStates[key] = state
        
        ensureTranscriptionDirectory()
        let url = transcriptionURL(for: memoId)
        
        let transcriptionData = TranscriptionData(
            memoId: memoId,
            state: state,
            text: state.text,
            lastUpdated: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(transcriptionData)
            try data.write(to: url)
            print("💾 TranscriptionRepository: Saved transcription state \(state.statusText) for memo \(memoId)")
        } catch {
            print("❌ TranscriptionRepository: Failed to save transcription state: \(error)")
        }
    }
    
    func getTranscriptionState(for memoId: UUID) -> TranscriptionState {
        let key = memoIdKey(for: memoId)
        
        if let cached = transcriptionStates[key] {
            print("🎯 TranscriptionRepository: Found cached transcription state for memo \(memoId)")
            return cached
        }
        
        let url = transcriptionURL(for: memoId)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let transcriptionData = try? JSONDecoder().decode(TranscriptionData.self, from: data) else {
            print("🔍 TranscriptionRepository: No saved transcription found for memo \(memoId)")
            transcriptionStates[key] = .notStarted
            return .notStarted
        }
        
        transcriptionStates[key] = transcriptionData.state
        print("💾 TranscriptionRepository: Loaded transcription state from disk for memo \(memoId)")
        return transcriptionData.state
    }
    
    func deleteTranscriptionData(for memoId: UUID) {
        let key = memoIdKey(for: memoId)
        let url = transcriptionURL(for: memoId)
        
        transcriptionStates.removeValue(forKey: key)
        try? FileManager.default.removeItem(at: url)
        
        print("🗑️ TranscriptionRepository: Deleted transcription data for memo \(memoId)")
    }
    
    func hasTranscriptionData(for memoId: UUID) -> Bool {
        let key = memoIdKey(for: memoId)
        
        if transcriptionStates[key] != nil {
            return true
        }
        
        let url = transcriptionURL(for: memoId)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    func getTranscriptionText(for memoId: UUID) -> String? {
        let state = getTranscriptionState(for: memoId)
        return state.text
    }
    
    func saveTranscriptionText(_ text: String, for memoId: UUID) {
        let state = TranscriptionState.completed(text)
        saveTranscriptionState(state, for: memoId)
    }
    
    func getTranscriptionMetadata(for memoId: UUID) -> [String: Any]? {
        // Prefer separate metadata file if available
        let metaURL = metadataURL(for: memoId)
        if FileManager.default.fileExists(atPath: metaURL.path),
           let data = try? Data(contentsOf: metaURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }

        // Fallback: derive minimal metadata from transcription file
        let url = transcriptionURL(for: memoId)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let transcriptionData = try? JSONDecoder().decode(TranscriptionData.self, from: data) else {
            return nil
        }
        return [
            "memoId": transcriptionData.memoId.uuidString,
            "state": transcriptionData.state.statusText,
            "text": transcriptionData.text ?? "",
            "lastUpdated": transcriptionData.lastUpdated
        ]
    }
    
    func saveTranscriptionMetadata(_ metadata: [String: Any], for memoId: UUID) {
        let url = metadataURL(for: memoId)
        do {
            let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted])
            try data.write(to: url)
            print("📝 TranscriptionRepository: Saved metadata for memo \(memoId) at \(url.lastPathComponent)")
        } catch {
            print("❌ TranscriptionRepository: Failed to save metadata: \(error)")
        }
    }
    
    func clearTranscriptionCache() {
        transcriptionStates.removeAll()
        print("🧹 TranscriptionRepository: Cleared transcription cache")
    }
    
    func getAllTranscriptionStates() -> [UUID: TranscriptionState] {
        var states: [UUID: TranscriptionState] = [:]
        
        for (key, state) in transcriptionStates {
            if let uuid = UUID(uuidString: key) {
                states[uuid] = state
            }
        }
        
        return states
    }
}

struct TranscriptionData: Codable {
    let memoId: UUID
    let state: TranscriptionState
    let text: String?
    let lastUpdated: Date
}
