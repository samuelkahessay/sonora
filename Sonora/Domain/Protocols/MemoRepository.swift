import Foundation
import Combine

protocol MemoRepository: ObservableObject {
    var memos: [Memo] { get set }
    var playingMemo: Memo? { get set }
    var isPlaying: Bool { get set }
    
    func loadMemos()
    func deleteMemo(_ memo: Memo)
    func playMemo(_ memo: Memo)
    func pausePlaying()
    func stopPlaying()
    func handleNewRecording(at url: URL)
    func getTranscriptionState(for memo: Memo) -> TranscriptionState
    func retryTranscription(for memo: Memo)
}