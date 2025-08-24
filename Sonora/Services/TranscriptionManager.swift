import Foundation
import Combine

@MainActor
class TranscriptionManager: ObservableObject {
    @Published var transcriptionStates: [String: TranscriptionState] = [:]
    
    private let transcriptionService = TranscriptionService()
    private let metadataManager = MemoMetadataManager()
    
    private func canonicalKey(for url: URL) -> String {
        return url.resolvingSymlinksInPath().standardizedFileURL.path
    }
    
    func getTranscriptionState(for memo: Memo) -> TranscriptionState {
        let urlKey = canonicalKey(for: memo.url)
        print("🔍 TranscriptionManager: Getting state for \(memo.filename)")
        print("🔍 TranscriptionManager: Canonical URL key: \(urlKey)")
        
        if let cached = transcriptionStates[urlKey] {
            print("🔍 TranscriptionManager: Found cached state: \(cached.statusText)")
            return cached
        }
        
        print("🔍 TranscriptionManager: No cached state, checking metadata...")
        let saved = metadataManager.getTranscriptionState(for: memo.url)
        print("🔍 TranscriptionManager: Loaded from metadata: \(saved.statusText)")
        transcriptionStates[urlKey] = saved
        return saved
    }
    
    func startTranscription(for memo: Memo) {
        print("🔄 TranscriptionManager: Starting transcription for \(memo.filename)")
        guard !getTranscriptionState(for: memo).isInProgress else { 
            print("⚠️ Transcription already in progress for \(memo.filename)")
            return 
        }
        
        transcriptionStates[canonicalKey(for: memo.url)] = .inProgress
        metadataManager.saveTranscriptionState(.inProgress, for: memo.url)
        objectWillChange.send()
        print("📝 Saved transcription state as in-progress")
        
        Task {
            do {
                let transcription = try await transcriptionService.transcribe(url: memo.url)
                print("✅ Transcription completed for \(memo.filename)")
                print("💾 Transcription text: \(transcription.prefix(100))...")
                
                await MainActor.run {
                    self.updateTranscriptionState(.completed(transcription), for: memo)
                }
            } catch {
                print("❌ Transcription failed for \(memo.filename): \(error.localizedDescription)")
                await MainActor.run {
                    self.updateTranscriptionState(.failed(error.localizedDescription), for: memo)
                }
            }
        }
    }
    
    func retryTranscription(for memo: Memo) {
        startTranscription(for: memo)
    }
    
    private func updateTranscriptionState(_ state: TranscriptionState, for memo: Memo) {
        let urlKey = canonicalKey(for: memo.url)
        print("📱 TranscriptionManager: Updating state for \(memo.filename)")
        print("📱 TranscriptionManager: Canonical URL key: \(urlKey)")
        print("📱 TranscriptionManager: New state: \(state.statusText)")
        print("📱 TranscriptionManager: Is completed: \(state.isCompleted)")
        
        transcriptionStates[urlKey] = state
        metadataManager.saveTranscriptionState(state, for: memo.url)
        
        print("📱 TranscriptionManager: State saved to memory and disk")
        print("📱 TranscriptionManager: Triggering UI update with objectWillChange")
        
        // Force immediate UI update by triggering @Published property change
        // This ensures views get the latest state immediately
        let currentStates = transcriptionStates
        transcriptionStates = currentStates
        
        print("📱 TranscriptionManager: UI update signal sent!")
    }
}