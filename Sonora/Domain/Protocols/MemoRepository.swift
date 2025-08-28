import Foundation
import Combine

protocol MemoRepository: ObservableObject {
    var objectWillChange: ObservableObjectPublisher { get }
    var memos: [DomainMemo] { get set }
    
    // Playback state
    var playingMemo: DomainMemo? { get }
    var isPlaying: Bool { get }
    func playMemo(_ memo: DomainMemo)
    func stopPlaying()
    
    // Persistence
    func loadMemos()
    func saveMemo(_ memo: DomainMemo)
    func deleteMemo(_ memo: DomainMemo)
    func getMemo(by id: UUID) -> DomainMemo?
    func getMemo(by url: URL) -> DomainMemo?
    func handleNewRecording(at url: URL)
    func updateMemoMetadata(_ memo: DomainMemo, metadata: [String: Any])
}
