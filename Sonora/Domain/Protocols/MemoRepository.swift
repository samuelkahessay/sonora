import Foundation
import Combine

@MainActor
protocol MemoRepository: ObservableObject {
    var objectWillChange: ObservableObjectPublisher { get }
    var memos: [Memo] { get set }
    
    // MARK: - Reactive Publishers (Swift 6 Compliant)
    
    /// Publisher for memo list changes - enables unified state management
    var memosPublisher: AnyPublisher<[Memo], Never> { get }
    
    // Playback state
    var playingMemo: Memo? { get }
    var isPlaying: Bool { get }
    func playMemo(_ memo: Memo)
    func stopPlaying()
    /// Seek playback position for the specified memo (no-op if not the active memo)
    func seek(to time: TimeInterval, for memo: Memo)
    /// Publishes periodic playback progress updates for the active memo
    var playbackProgressPublisher: AnyPublisher<PlaybackProgress, Never> { get }
    
    // Persistence
    func loadMemos()
    func saveMemo(_ memo: Memo)
    func deleteMemo(_ memo: Memo)
    func getMemo(by id: UUID) -> Memo?
    func getMemo(by url: URL) -> Memo?
    @discardableResult
    func handleNewRecording(at url: URL) -> Memo
    func updateMemoMetadata(_ memo: Memo, metadata: [String: Any])
    func renameMemo(_ memo: Memo, newTitle: String)
}

/// Playback progress update
struct PlaybackProgress: Equatable, Sendable {
    let memoId: UUID
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
}
