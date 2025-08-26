import Foundation
import Combine

protocol TranscriptionServiceProtocol: ObservableObject {
    var transcriptionStates: [String: TranscriptionState] { get set }
    
    func getTranscriptionState(for memo: Memo) -> TranscriptionState
    func startTranscription(for memo: Memo)
    func retryTranscription(for memo: Memo)
}