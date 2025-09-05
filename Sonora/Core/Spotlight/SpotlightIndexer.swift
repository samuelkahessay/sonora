import Foundation
@preconcurrency import CoreSpotlight
import UniformTypeIdentifiers

// MARK: - Protocol

@MainActor
protocol SpotlightIndexing: AnyObject {
    func index(memoID: UUID) async
    func delete(memoID: UUID) async
    func reindexAll() async
}

// MARK: - Implementation

@MainActor
final class SpotlightIndexer: SpotlightIndexing {
    private let logger: any LoggerProtocol
    private let memoRepository: any MemoRepository
    private let transcriptionRepository: any TranscriptionRepository
    private let analysisRepository: any AnalysisRepository

    // Core Spotlight queue isolation to prevent reentrancy issues
    private let csQueue = DispatchQueue(label: "com.samuelkahessay.Sonora.spotlight", qos: .utility)

    // Debounce/throttle state
    private var debounceTasks: [UUID: Task<Void, Never>] = [:]
    private var lastIndexTime: [UUID: Date] = [:]
    private let debounceInterval: TimeInterval = 1.5
    private let throttleInterval: TimeInterval = 5.0

    init(
        logger: any LoggerProtocol = Logger.shared,
        memoRepository: any MemoRepository,
        transcriptionRepository: any TranscriptionRepository,
        analysisRepository: any AnalysisRepository
    ) {
        self.logger = logger
        self.memoRepository = memoRepository
        self.transcriptionRepository = transcriptionRepository
        self.analysisRepository = analysisRepository
    }

    // MARK: - Core Spotlight Queue Isolation
    
    /// Queue-isolated wrapper for indexing Core Spotlight items
    private func cs_index(_ items: [CSSearchableItem]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            csQueue.async {
                CSSearchableIndex.default().indexSearchableItems(items) { error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }
        }
    }
    
    /// Queue-isolated wrapper for deleting Core Spotlight items by identifier
    private func cs_delete(identifiers: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            csQueue.async {
                CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers) { error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }
        }
    }
    
    /// Queue-isolated wrapper for deleting Core Spotlight items by domain
    private func cs_deleteDomain(_ domainIDs: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            csQueue.async {
                CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: domainIDs) { error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }
        }
    }

    // MARK: - Public API
    func index(memoID: UUID) async {
        guard AppConfiguration.shared.searchIndexingEnabled else {
            logger.debug("Spotlight indexing disabled by user setting", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight"]))
            return
        }

        // Debounce per ID
        debounceTasks[memoID]?.cancel()
        let task = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.debounceInterval * 1_000_000_000))
            await self.performIndex(memoID: memoID)
        }
        debounceTasks[memoID] = task
    }

    func delete(memoID: UUID) async {
        guard AppConfiguration.shared.searchIndexingEnabled else { return }
        guard CSSearchableIndex.isIndexingAvailable() else {
            logger.warning("CSSearchableIndex unavailable; skipping delete", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight"]), error: nil)
            return
        }
        let idStr = memoID.uuidString
        do {
            try await cs_delete(identifiers: [idStr])
            logger.info("Spotlight: deleted item \(idStr)", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight"]))
        } catch {
            logger.warning("Spotlight delete failed", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight", "memoId": idStr]), error: error)
        }
    }

    func reindexAll() async {
        guard AppConfiguration.shared.searchIndexingEnabled else { return }
        guard CSSearchableIndex.isIndexingAvailable() else {
            logger.warning("CSSearchableIndex unavailable; skipping reindexAll", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight"]), error: nil)
            return
        }
        let start = Date()
        do {
            try await cs_deleteDomain(["memo"])
        } catch {
            logger.warning("Spotlight domain delete failed; proceeding", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight"]), error: error)
        }
        let all = memoRepository.memos
        logger.info("Spotlight: reindexing \(all.count) memos", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight"]))

        let chunkSize = 500
        var idx = 0
        while idx < all.count {
            let chunk = Array(all[idx..<min(idx+chunkSize, all.count)])
            var items: [CSSearchableItem] = []
            for memo in chunk {
                if let item = await self.buildSearchableItem(for: memo) {
                    items.append(item)
                }
            }
            do {
                try await cs_index(items)
            } catch {
                logger.warning("Spotlight batch index failed", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight", "batchStart": idx]), error: error)
            }
            idx += chunkSize
        }
        let duration = Date().timeIntervalSince(start)
        logger.info("Spotlight reindex completed in \(String(format: "%.2f", duration))s", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight"]))
    }

    // MARK: - Private
    private func performIndex(memoID: UUID) async {
        // Throttle duplicate index calls
        if let last = lastIndexTime[memoID], Date().timeIntervalSince(last) < throttleInterval {
            logger.debug("Spotlight: throttled duplicate index for \(memoID)", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight"]))
            return
        }
        lastIndexTime[memoID] = Date()

        guard CSSearchableIndex.isIndexingAvailable() else {
            logger.warning("CSSearchableIndex unavailable; skipping index", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight"]), error: nil)
            return
        }
        guard let memo = memoRepository.getMemo(by: memoID) else {
            logger.warning("Spotlight: memo not found for indexing", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight", "memoId": memoID.uuidString]), error: nil)
            return
        }
        // Respect privacy flag if provided via metadata; skip if isPrivate == true
        if let meta = transcriptionRepository.getTranscriptionMetadata(for: memoID), let isPrivate = meta.isPrivate, isPrivate {
            logger.info("Spotlight: skipping private memo", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight", "memoId": memoID.uuidString]))
            return
        }
        guard let item = await buildSearchableItem(for: memo) else { return }
        
        do {
            try await cs_index([item])
            logger.info("Spotlight: indexed memo \(memoID)", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight"]))
        } catch {
            logger.warning("Spotlight index failed", category: .service, context: LogContext(additionalInfo: ["component": "Spotlight", "memoId": memoID.uuidString]), error: error)
        }
    }

    private func buildSearchableItem(for memo: Memo) async -> CSSearchableItem? {
        let attrs = CSSearchableItemAttributeSet(contentType: UTType.audio)
        let idStr = memo.id.uuidString
        attrs.title = memoDisplayTitle(memo)
        attrs.contentDescription = await contentDescription(for: memo)
        attrs.keywords = ["voice", "memo", "transcript"]
        attrs.contentURL = URL(string: "sonora://memo/\(idStr)")
        attrs.contentCreationDate = memo.creationDate
        attrs.contentModificationDate = memo.creationDate
        // lastUsedDate best-effort from metadata if present
        if let meta = transcriptionRepository.getTranscriptionMetadata(for: memo.id), let last = meta.lastOpenedAt {
            attrs.lastUsedDate = last
        }
        return CSSearchableItem(uniqueIdentifier: idStr, domainIdentifier: "memo", attributeSet: attrs)
    }

    private func memoDisplayTitle(_ memo: Memo) -> String {
        // No explicit title in model; use friendly date label
        let formatter = ISO8601DateFormatter()
        return "Voice Memo – \(formatter.string(from: memo.creationDate))"
    }

    private func contentDescription(for memo: Memo) async -> String {
        // Prefer summary if available; else first 160 chars of transcript; else fallback
        if let t = transcriptionRepository.getTranscriptionText(for: memo.id), !t.isEmpty {
            let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 160 {
                let idx = trimmed.index(trimmed.startIndex, offsetBy: 160)
                return String(trimmed[..<idx])
            }
            return trimmed
        }
        return "Voice memo"
    }
}
