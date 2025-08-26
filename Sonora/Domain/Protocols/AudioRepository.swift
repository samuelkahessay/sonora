import Foundation
import AVFoundation
import Combine

protocol AudioRepository: ObservableObject {
    var playingMemo: Memo? { get set }
    var isPlaying: Bool { get set }
    
    func loadAudioFiles() -> [Memo]
    func deleteAudioFile(at url: URL) throws
    func saveAudioFile(from sourceURL: URL, to destinationURL: URL) throws
    func getAudioMetadata(for url: URL) throws -> (duration: TimeInterval, creationDate: Date)
    
    func playAudio(at url: URL) throws
    func pauseAudio()
    func stopAudio()
    func isAudioPlaying(for memo: Memo) -> Bool
    
    func getDocumentsDirectory() -> URL
}