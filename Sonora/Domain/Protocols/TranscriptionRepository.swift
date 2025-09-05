import Foundation
import Combine

/// State change event for transcription updates
@MainActor
struct TranscriptionStateChange: Sendable {
    let memoId: UUID
    let previousState: TranscriptionState?
    let currentState: TranscriptionState
    let timestamp: Date
    
    init(memoId: UUID, previousState: TranscriptionState?, currentState: TranscriptionState) {
        self.memoId = memoId
        self.previousState = previousState
        self.currentState = currentState
        self.timestamp = Date()
    }
}

@MainActor
protocol TranscriptionRepository: ObservableObject {
    var objectWillChange: ObservableObjectPublisher { get }
    var transcriptionStates: [String: TranscriptionState] { get set }
    
    /// Publisher for transcription state changes - Swift 6 compliant event-driven updates
    var stateChangesPublisher: AnyPublisher<TranscriptionStateChange, Never> { get }
    
    func saveTranscriptionState(_ state: TranscriptionState, for memoId: UUID)
    func getTranscriptionState(for memoId: UUID) -> TranscriptionState
    func deleteTranscriptionData(for memoId: UUID)
    func hasTranscriptionData(for memoId: UUID) -> Bool
    func getTranscriptionText(for memoId: UUID) -> String?
    func saveTranscriptionText(_ text: String, for memoId: UUID)
    func getTranscriptionMetadata(for memoId: UUID) -> TranscriptionMetadata?
    func saveTranscriptionMetadata(_ metadata: TranscriptionMetadata, for memoId: UUID)
    func clearTranscriptionCache()
    func getAllTranscriptionStates() -> [UUID: TranscriptionState]
    /// Batched retrieval for a set of memos to avoid N+1 fetches
    func getTranscriptionStates(for memoIds: [UUID]) -> [UUID: TranscriptionState]
    
    /// Convenience method to get state changes for a specific memo
    func stateChangesPublisher(for memoId: UUID) -> AnyPublisher<TranscriptionStateChange, Never>
}
