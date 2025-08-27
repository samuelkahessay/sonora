import Foundation
import Combine

@MainActor
class TranscriptionManager: ObservableObject, TranscriptionServiceProtocol {
    @Published var transcriptionStates: [String: TranscriptionState] = [:]
    
    private let transcriptionService = TranscriptionService()
    private let transcriptionRepository: TranscriptionRepository
    
    init(transcriptionRepository: TranscriptionRepository) {
        self.transcriptionRepository = transcriptionRepository
    }
    
    // CRITICAL FIX: Use UUID-based keys to match repository system
    private func memoKey(for memo: Memo) -> String {
        return memo.id.uuidString
    }
    
    func getTranscriptionState(for memo: Memo) -> TranscriptionState {
        let memoKey = memoKey(for: memo)
        print("🔍 TranscriptionManager: Getting state for \(memo.filename)")
        print("🔍 TranscriptionManager: Memo ID key: \(memoKey)")
        
        if let cached = transcriptionStates[memoKey] {
            print("🔍 TranscriptionManager: Found cached state: \(cached.statusText)")
            return cached
        }
        
        print("🔍 TranscriptionManager: No cached state, checking repository...")
        let saved = transcriptionRepository.getTranscriptionState(for: memo.id)
        print("🔍 TranscriptionManager: Loaded from repository: \(saved.statusText)")
        transcriptionStates[memoKey] = saved
        return saved
    }
    
    func startTranscription(for memo: Memo) {
        print("🔄 TranscriptionManager: Starting transcription for \(memo.filename)")
        guard !getTranscriptionState(for: memo).isInProgress else { 
            print("⚠️ Transcription already in progress for \(memo.filename)")
            return 
        }
        
        transcriptionStates[memoKey(for: memo)] = .inProgress
        transcriptionRepository.saveTranscriptionState(.inProgress, for: memo.id)
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
        let memoKey = memoKey(for: memo)
        print("📱 TranscriptionManager: Updating state for \(memo.filename)")
        print("📱 TranscriptionManager: Memo ID key: \(memoKey)")
        print("📱 TranscriptionManager: New state: \(state.statusText)")
        print("📱 TranscriptionManager: Is completed: \(state.isCompleted)")
        
        transcriptionStates[memoKey] = state
        transcriptionRepository.saveTranscriptionState(state, for: memo.id)
        
        // If transcription is completed, save the text
        if case .completed(let text) = state {
            transcriptionRepository.saveTranscriptionText(text, for: memo.id)
            print("💾 TranscriptionManager: Saved transcription text to repository")
        }
        
        print("📱 TranscriptionManager: State saved to memory and repository")
        print("📱 TranscriptionManager: Triggering UI update with objectWillChange")
        
        // Force immediate UI update by triggering @Published property change
        // This ensures views get the latest state immediately
        let currentStates = transcriptionStates
        transcriptionStates = currentStates
        
        print("📱 TranscriptionManager: UI update signal sent!")
    }
}