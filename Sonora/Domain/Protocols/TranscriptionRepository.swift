import Foundation
import Combine

@MainActor
protocol TranscriptionRepository: ObservableObject {
    var transcriptionStates: [String: TranscriptionState] { get set }
    
    func saveTranscriptionState(_ state: TranscriptionState, for memoId: UUID)
    func getTranscriptionState(for memoId: UUID) -> TranscriptionState
    func deleteTranscriptionData(for memoId: UUID)
    func hasTranscriptionData(for memoId: UUID) -> Bool
    func getTranscriptionText(for memoId: UUID) -> String?
    func saveTranscriptionText(_ text: String, for memoId: UUID)
    func getTranscriptionMetadata(for memoId: UUID) -> [String: Any]?
    func saveTranscriptionMetadata(_ metadata: [String: Any], for memoId: UUID)
    func clearTranscriptionCache()
    func getAllTranscriptionStates() -> [UUID: TranscriptionState]
}
