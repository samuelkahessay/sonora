import Combine
import Foundation

@MainActor
protocol MemoRepository {
    var memos: [Memo] { get }

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

    /// Publishes playback state changes (playing memo and play/pause state)
    var playbackStatePublisher: AnyPublisher<MemoPlaybackState, Never> { get }

    /// Publishes periodic playback progress updates for the active memo
    var playbackProgressPublisher: AnyPublisher<PlaybackProgress, Never> { get }

    // Persistence
    func loadMemos()
    /// Search memos by query across filename, customTitle, and transcription text
    /// - Parameter query: Free text query. Empty string should return all memos.
    /// - Returns: Matching memos (unsorted or repository default sort)
    func searchMemos(query: String) -> [Memo]
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

/// Memo playback state update (playing memo and play/pause state)
struct MemoPlaybackState: Equatable, Sendable {
    let playingMemo: Memo?
    let isPlaying: Bool
}
