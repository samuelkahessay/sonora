import AVFoundation
import Combine
import Foundation
import SwiftData

@MainActor
final class MemoRepositoryImpl: ObservableObject, MemoRepository {
    @Published var memos: [Memo] = []

    // Lightweight in-memory cache for common list queries
    private var memosCache: [Memo]?
    private var memosCacheTime: Date?
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Reactive Publishers (Swift 6 Compliant)

    /// Publisher for memo list changes - enables unified state management
    var memosPublisher: AnyPublisher<[Memo], Never> {
        $memos.eraseToAnyPublisher()
    }

    // Playback state
    @Published private(set) var playingMemo: Memo?
    @Published private(set) var isPlaying: Bool = false

    // Transcription is handled via dedicated repository and use cases
    private let transcriptionRepository: any TranscriptionRepository
    private let autoTitleJobRepository: any AutoTitleJobRepository
    private let context: ModelContext

    private var player: AVAudioPlayer?
    private var playbackTimer: Timer?
    private let playbackSubject = PassthroughSubject<PlaybackProgress, Never>()

    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let memosDirectoryPath: URL

    // MARK: - Initialization
    init(
        context: ModelContext,
        transcriptionRepository: any TranscriptionRepository,
        autoTitleJobRepository: any AutoTitleJobRepository
    ) {
        self.context = context
        self.transcriptionRepository = transcriptionRepository
        self.autoTitleJobRepository = autoTitleJobRepository

        self.memosDirectoryPath = documentsPath.appendingPathComponent("Memos")
        createDirectoriesIfNeeded()
        loadMemos()

        autoTitleJobRepository.jobsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshAutoTitleStatesFromJobs()
            }
            .store(in: &cancellables)
    }

    // MARK: - Directory Management
    private func createDirectoriesIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: memosDirectoryPath,
                                                   withIntermediateDirectories: true,
                                                   attributes: nil)
            print("✅ MemoRepository: Created Memos directory at \(memosDirectoryPath.path)")
        } catch {
            print("❌ MemoRepository: Failed to create Memos directory: \(error)")
        }
    }

    private func memoDirectoryPath(for memoId: UUID) -> URL {
        memosDirectoryPath.appendingPathComponent(memoId.uuidString)
    }

    private func audioFilePath(for memoId: UUID) -> URL {
        memoDirectoryPath(for: memoId).appendingPathComponent("audio.m4a")
    }

    // SwiftData-backed: no sidecar metadata file

    // MARK: - Playback
    func playMemo(_ memo: Memo) {
        // Handle pause/resume toggle for same memo
        if playingMemo?.id == memo.id && isPlaying {
            pausePlaying()
            return
        }

        // Resume paused memo
        if playingMemo?.id == memo.id && !isPlaying && player != nil {
            player?.play()
            isPlaying = true
            print("▶️ MemoRepository: Resumed \(memo.filename)")
            return
        }

        // Stop current if different memo
        if let current = playingMemo, current.id != memo.id {
            stopPlaying()
        }

        do {
            // Ensure audio session is configured for playback (speaker)
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true)
            } catch {
                print("⚠️ MemoRepository: Failed to configure playback session: \(error)")
            }

            let audio = try AVAudioPlayer(contentsOf: memo.fileURL)
            player = audio
            audio.prepareToPlay()
            audio.play()
            playingMemo = memo
            isPlaying = true
            print("▶️ MemoRepository: Playing \(memo.filename)")
            startPlaybackTimer()
            Task { @MainActor in
                self.publishProgress(forcedMemo: memo)
            }

        } catch {
            print("❌ MemoRepository: Failed to play \(memo.filename): \(error)")
            stopPlaying()

        }
    }

    func pausePlaying() {
        player?.pause()
        isPlaying = false
        print("⏸️ MemoRepository: Paused playback")
        Task { @MainActor in
            self.publishProgress()
        }
    }

    func stopPlaying() {
        player?.stop()
        player = nil
        isPlaying = false
        playingMemo = nil
        print("⏹️ MemoRepository: Stopped playback")
        stopPlaybackTimer()
    }

    func seek(to time: TimeInterval, for memo: Memo) {
        // Ensure player is prepared for this memo even if not currently playing
        if playingMemo?.id != memo.id || player == nil {
            do {
                // Configure session but do not start playback
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playback, mode: .default, options: [])
                try? session.setActive(true)

                let audio = try AVAudioPlayer(contentsOf: memo.fileURL)
                player = audio
                audio.prepareToPlay()
                playingMemo = memo
                isPlaying = false
            } catch {
                print("❌ MemoRepository: Failed to prepare player for seek: \(error)")
                return
            }
        }
        guard let player = player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        Task { @MainActor in
            self.publishProgress(forcedMemo: memo)
        }
    }

    var playbackProgressPublisher: AnyPublisher<PlaybackProgress, Never> {
        playbackSubject.eraseToAnyPublisher()
    }

    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.publishProgress()
            }
        }
        if let timer = playbackTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func publishProgress(forcedMemo memo: Memo? = nil) {
        guard let memo = memo ?? playingMemo, let player = player else { return }
        let progress = PlaybackProgress(
            memoId: memo.id,
            currentTime: player.currentTime,
            duration: player.duration,
            isPlaying: isPlaying
        )
        playbackSubject.send(progress)
    }

    // MARK: - File Helpers

    private func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - SwiftData Helpers
    private func fetchMemoModel(id: UUID) -> MemoModel? {
        let descriptor = FetchDescriptor<MemoModel>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    private func mapToDomain(_ model: MemoModel) -> Memo {
        // Always derive the canonical audio URL from current container + memo id
        let url = audioFilePath(for: model.id)
        // Status injected via batched map when available; default to repository lookup as fallback
        let status = mapToDomainStatus(transcriptionRepository.getTranscriptionState(for: model.id))
        return Memo(
            id: model.id,
            filename: model.filename,
            fileURL: url,
            creationDate: model.creationDate,
            durationSeconds: model.duration,
            transcriptionStatus: status,
            analysisResults: [],
            customTitle: model.customTitle,
            shareableFileName: model.shareableFileName,
            autoTitleState: autoTitleState(for: model.id)
        )
    }

    private func mapToDomainStatus(_ state: TranscriptionState) -> DomainTranscriptionStatus {
        switch state {
        case .notStarted: return .notStarted
        case .inProgress: return .inProgress
        case .completed(let text): return .completed(text)
        case .failed(let error): return .failed(error)
        }
    }

    private func autoTitleState(for memoId: UUID) -> TitleGenerationState {
        guard let job = autoTitleJobRepository.job(for: memoId) else { return .idle }
        return TitleGenerationState(job: job)
    }

    private func refreshAutoTitleStatesFromJobs() {
        let updated = memos.map { memo -> Memo in
            let state = autoTitleState(for: memo.id)
            return memo.autoTitleState == state ? memo : memo.withAutoTitleState(state)
        }

        guard updated != memos else { return }

        memos = updated
        memosCache = updated
        memosCacheTime = Date()
    }

    func loadMemos() {
        // Serve cached list immediately if fresh (perceived latency win)
        if let cache = memosCache, let ts = memosCacheTime, Date().timeIntervalSince(ts) < 3 {
            self.memos = cache
        }
        do {
            let descriptor = FetchDescriptor<MemoModel>(sortBy: [SortDescriptor(\.creationDate, order: .reverse)])
            let models = try context.fetch(descriptor)
            let ids = models.map { $0.id }

            // Identify orphaned records first (based on canonical path in current container)
            let orphanModels: [MemoModel] = models.filter { model in
                let url = audioFilePath(for: model.id)
                return !FileManager.default.fileExists(atPath: url.path)
            }

            // Batch fetch transcription states to avoid N+1
            let states = transcriptionRepository.getTranscriptionStates(for: ids)
            let mapped: [Memo] = models.compactMap { model in
                // Recompute canonical path from current container
                let url = audioFilePath(for: model.id)
                // Filter out orphaned records (container changed or file removed)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    return nil
                }
                let state = states[model.id] ?? transcriptionRepository.getTranscriptionState(for: model.id)
                return Memo(
                    id: model.id,
                    filename: model.filename,
                    fileURL: url,
                    creationDate: model.creationDate,
                    durationSeconds: model.duration,
                    transcriptionStatus: mapToDomainStatus(state),
                    analysisResults: [],
                    customTitle: model.customTitle,
                    shareableFileName: model.shareableFileName,
                    autoTitleState: autoTitleState(for: model.id)
                )
            }
            self.memos = mapped
            self.memosCache = mapped
            self.memosCacheTime = Date()
            print("✅ MemoRepository: Loaded \(mapped.count) memos from SwiftData (batched states)")

            // Background cleanup for orphaned SwiftData records; single summary log
            if !orphanModels.isEmpty {
                let count = orphanModels.count
                Task { @MainActor in
                    orphanModels.forEach { context.delete($0) }
                    do { try context.save() } catch { /* best-effort */ }
                    print("🧹 MemoRepository: Orphan cleanup removed \(count) memo record(s) (missing audio files)")
                }
            }
        } catch {
            print("❌ MemoRepository: Failed to fetch memos from SwiftData: \(error)")
            self.memos = []
            self.memosCache = nil
        }
    }

    // MARK: - Search
    /// Search memos by query across filename, custom title, and full transcript text
    /// Returns memos sorted by creation date (newest first)
    func searchMemos(query: String) -> [Memo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Fast path: empty query returns current list (already sorted)
        if trimmed.isEmpty { return memos }

        do {
            let q = trimmed
            let predicate = #Predicate<MemoModel> { model in
                (model.customTitle?.localizedStandardContains(q) ?? false)
                || model.filename.localizedStandardContains(q)
                || (model.transcription?.fullTranscript.localizedStandardContains(q) ?? false)
            }
            let descriptor = FetchDescriptor<MemoModel>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.creationDate, order: .reverse)]
            )

            let models = try context.fetch(descriptor)

            // Batch fetch transcription states to avoid N+1
            let ids = models.map { $0.id }
            let states = transcriptionRepository.getTranscriptionStates(for: ids)

            let mapped: [Memo] = models.compactMap { model in
                let url = audioFilePath(for: model.id)
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                let state = states[model.id] ?? transcriptionRepository.getTranscriptionState(for: model.id)
                return Memo(
                    id: model.id,
                    filename: model.filename,
                    fileURL: url,
                    creationDate: model.creationDate,
                    durationSeconds: model.duration,
                    transcriptionStatus: mapToDomainStatus(state),
                    analysisResults: [],
                    customTitle: model.customTitle,
                    shareableFileName: model.shareableFileName,
                    autoTitleState: autoTitleState(for: model.id)
                )
            }
            return mapped
        } catch {
            print("❌ MemoRepository: Search failed with error: \(error)")
            return []
        }
    }

    private func saveAndReturn(_ memo: Memo) -> Memo {
        do {
            let memoDirectoryPath = memoDirectoryPath(for: memo.id)
            let audioDestination = audioFilePath(for: memo.id)

            // Create memo directory
            try FileManager.default.createDirectory(at: memoDirectoryPath,
                                                   withIntermediateDirectories: true,
                                                   attributes: nil)

            // Copy audio file if it's not already in the correct location
            if memo.fileURL != audioDestination {
                if fileExists(at: audioDestination) {
                    try FileManager.default.removeItem(at: audioDestination)
                }
                try FileManager.default.copyItem(at: memo.fileURL, to: audioDestination)
                print("📁 MemoRepository: Audio file copied to \(audioDestination.lastPathComponent)")
            }

            // Get duration using AVAudioFile with readiness helper
            let duration: TimeInterval = {
                do {
                    let audioFile = try AudioReadiness.openIfReady(url: audioDestination, maxWait: 0.4)
                    let frames = Double(audioFile.length)
                    let rate = audioFile.fileFormat.sampleRate
                    let secs = frames / rate
                    return secs
                } catch {
                    return 0
                }
            }()

            // Upsert SwiftData model
            if let model = fetchMemoModel(id: memo.id) {
                model.filename = memo.filename
                model.audioFilePath = audioDestination.path
                model.customTitle = memo.customTitle
                model.shareableFileName = memo.shareableFileName
                model.duration = duration.isFinite ? duration : nil
                model.creationDate = memo.creationDate
            } else {
                let shareName: String? = {
                    if let title = memo.customTitle { return FileNameSanitizer.sanitize(title) }
                    return nil
                }()
                let model = MemoModel(
                    id: memo.id,
                    creationDate: memo.creationDate,
                    customTitle: memo.customTitle,
                    filename: memo.filename,
                    audioFilePath: audioDestination.path,
                    duration: duration.isFinite ? duration : nil,
                    shareableFileName: shareName
                )
                context.insert(model)
            }
            try context.save()

            // Construct canonical saved memo
            let savedMemo = Memo(
                id: memo.id,
                filename: memo.filename,
                fileURL: audioDestination,
                creationDate: memo.creationDate,
                durationSeconds: duration.isFinite ? duration : nil,
                transcriptionStatus: memo.transcriptionStatus,
                analysisResults: memo.analysisResults,
                customTitle: memo.customTitle,
                shareableFileName: memo.shareableFileName,
                autoTitleState: autoTitleState(for: memo.id)
            )

            // Update in-memory list
            if let idx = memos.firstIndex(where: { $0.id == memo.id }) {
                memos[idx] = savedMemo
            } else {
                memos.append(savedMemo)
                memos.sort { $0.recordingEndDate > $1.recordingEndDate }
                print("📝 MemoRepository: Added memo \(savedMemo.filename) to in-memory list with ID \(savedMemo.id)")
            }

            print("✅ MemoRepository: Successfully saved memo \(memo.filename) [SwiftData]")
            // Invalidate list cache
            memosCache = nil; memosCacheTime = nil
            return savedMemo

        } catch {
            print("❌ MemoRepository: Failed to save memo \(memo.filename): \(error)")
            return memo
        }
    }

    func saveMemo(_ memo: Memo) {
        _ = saveAndReturn(memo)
    }

    func deleteMemo(_ memo: Memo) {
        do {
            if playingMemo?.id == memo.id {
                stopPlaying()
            }

            let memoDirectory = memoDirectoryPath(for: memo.id)

            // Remove entire memo directory
            if fileExists(at: memoDirectory) {
                try FileManager.default.removeItem(at: memoDirectory)
                print("🗑️ MemoRepository: Deleted memo directory for \(memo.filename)")
            }

            // Delete SwiftData model (cascades to related data)
            if let model = fetchMemoModel(id: memo.id) {
                context.delete(model)
                try context.save()
            }

            // Update in-memory list
            memos.removeAll { $0.id == memo.id }

            print("✅ MemoRepository: Successfully deleted memo \(memo.filename)")
            // Invalidate list cache
            memosCache = nil; memosCacheTime = nil

        } catch {
            print("❌ MemoRepository: Failed to delete memo \(memo.filename): \(error)")
        }
    }

    func getMemo(by id: UUID) -> Memo? {
        if let model = fetchMemoModel(id: id) { return mapToDomain(model) }
        return nil
    }

    func getMemo(by url: URL) -> Memo? {
        let descriptor = FetchDescriptor<MemoModel>(predicate: #Predicate { $0.audioFilePath == url.path })
        if let model = try? context.fetch(descriptor).first { return mapToDomain(model) }
        return nil
    }

    @discardableResult
    func handleNewRecording(at url: URL) -> Memo {
        print("📁 MemoRepository: 🚨 NEW RECORDING RECEIVED - STARTING AUTO-TRANSCRIPTION FLOW")
        print("📁 MemoRepository: File URL: \(url.lastPathComponent)")
        print("📁 MemoRepository: Full path: \(url.path)")

        // Verify file exists and is accessible
        guard fileExists(at: url) else {
            print("❌ MemoRepository: Recording file does not exist at \(url.path)")
            return Memo(filename: url.lastPathComponent, fileURL: url, creationDate: Date())
        }

        do {
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
            let creationDate = resourceValues.creationDate ?? Date()
            let fileSize = resourceValues.fileSize ?? 0

            print("📊 MemoRepository: File size: \(fileSize) bytes")

            // Verify file has content
            guard fileSize > 0 else {
                print("⚠️ MemoRepository: Recording file is empty, skipping")
                return Memo(filename: url.lastPathComponent, fileURL: url, creationDate: creationDate)
            }

            let newMemo = Memo(
                filename: url.lastPathComponent,
                fileURL: url,
                creationDate: creationDate
            )

            print("💾 MemoRepository: Saving new recording as memo \(newMemo.filename)")
            let saved = saveAndReturn(newMemo)

            // Auto-transcription is orchestrated via memoCreated event to avoid duplicate triggers
            print("✅ MemoRepository: Successfully processed new recording")
            return saved

        } catch {
            print("❌ MemoRepository: Failed to process new recording: \(error)")
            return Memo(filename: url.lastPathComponent, fileURL: url, creationDate: Date())
        }
    }

    func updateMemoMetadata(_ memo: Memo, metadata: [String: Any]) {
        // SwiftData-backed repo: interpret known keys here if needed.
        // For now, log and ignore to maintain signature.
        print("📝 MemoRepository: Metadata update requested (ignored in SwiftData migration) for memo \(memo.filename) — data: \(metadata)")
    }

    func renameMemo(_ memo: Memo, newTitle: String) {
        let sanitizedTitle = newTitle.isEmpty ? nil : newTitle
        if let model = fetchMemoModel(id: memo.id) {
            model.customTitle = sanitizedTitle
            model.shareableFileName = sanitizedTitle.flatMap { FileNameSanitizer.sanitize($0) }
            do { try context.save() } catch { print("❌ MemoRepository: Failed to rename memo in SwiftData: \(error)") }
        }
        // Update in-memory memo as well
        if let index = memos.firstIndex(where: { $0.id == memo.id }) {
            let updatedMemo = memos[index].withCustomTitle(sanitizedTitle)
            memos[index] = updatedMemo
            objectWillChange.send()
            let displayText = sanitizedTitle ?? "default"
            let shareableText = sanitizedTitle.flatMap { FileNameSanitizer.sanitize($0) } ?? "default filename"
            print("✅ MemoRepository: Successfully renamed memo to '\(displayText)' with shareable filename '\(shareableText)'")
        }
        // Invalidate list cache
        memosCache = nil; memosCacheTime = nil
    }

}
