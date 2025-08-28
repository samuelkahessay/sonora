import Foundation
import Combine

@MainActor
protocol MemoRepository: ObservableObject {
    var objectWillChange: ObservableObjectPublisher { get }
    var memos: [Memo] { get set }
    
    // Playback state
    var playingMemo: Memo? { get }
    var isPlaying: Bool { get }
    func playMemo(_ memo: Memo)
    func stopPlaying()
    
    // Persistence
    func loadMemos()
    func saveMemo(_ memo: Memo)
    func deleteMemo(_ memo: Memo)
    func getMemo(by id: UUID) -> Memo?
    func getMemo(by url: URL) -> Memo?
    func handleNewRecording(at url: URL)
    func updateMemoMetadata(_ memo: Memo, metadata: [String: Any])
}
