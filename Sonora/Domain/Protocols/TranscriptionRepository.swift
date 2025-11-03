import Combine
import Foundation

/// State change event for transcription updates
/// Sendable for cross-actor boundary passing
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

/// Transcription repository protocol for managing transcription state and persistence.
/// Protocol is actor-agnostic (Sendable) - implementations choose their isolation.
protocol TranscriptionRepository: Sendable {
    var transcriptionStates: [String: TranscriptionState] { get async }

    /// Publisher for transcription state changes - Swift 6 compliant event-driven updates
    var stateChangesPublisher: AnyPublisher<TranscriptionStateChange, Never> { get }

    func saveTranscriptionState(_ state: TranscriptionState, for memoId: UUID) async
    func getTranscriptionState(for memoId: UUID) async -> TranscriptionState
    func deleteTranscriptionData(for memoId: UUID) async
    func getTranscriptionText(for memoId: UUID) async -> String?
    func saveTranscriptionText(_ text: String, for memoId: UUID) async
    func getTranscriptionMetadata(for memoId: UUID) async -> TranscriptionMetadata?
    func saveTranscriptionMetadata(_ metadata: TranscriptionMetadata, for memoId: UUID) async
    func clearTranscriptionCache() async
    /// Batched retrieval for a set of memos to avoid N+1 fetches
    func getTranscriptionStates(for memoIds: [UUID]) async -> [UUID: TranscriptionState]

    /// Convenience method to get state changes for a specific memo
    func stateChangesPublisher(for memoId: UUID) -> AnyPublisher<TranscriptionStateChange, Never>
}
