import Foundation

// MARK: - Stable Keys for Detections
// We need a deterministic key to track handled detections across partial streams.
// Using model-provided transient IDs (often random UUIDs) causes re-appearance.
// The stable key combines: kind + normalized source text/title + coarse date.

internal enum DetectionKeyBuilder {
    private static func normalize(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func dateKey(_ date: Date?) -> String {
        guard let date else { return "" }
        // Coarse date for stability (minute resolution is enough for our UX)
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df.string(from: date)
    }

    static func forUI(kind: ActionItemDetectionKind, sourceQuote: String, fallbackTitle: String, date: Date?) -> String {
        let base = normalize(sourceQuote.isEmpty ? fallbackTitle : sourceQuote)
        let when = dateKey(date)
        return "\(kind.rawValue)|\(base)|\(when)"
    }

    static func forDomain(_ det: ActionItemDetection) -> String {
        forUI(kind: det.kind, sourceQuote: det.sourceQuote, fallbackTitle: det.title, date: det.suggestedDate)
    }
}

// Support types used by DistillResultView's action item detections

internal struct DistillCreatedArtifact: Equatable {
    let kind: ActionItemDetectionKind
    let identifier: String
}

internal struct DistillAddedRecord: Identifiable, Equatable {
    let id: String
    let text: String
}

// Persistently remember which detections were added (per memo)
internal struct DistillHandledDetectionsStore {
    struct Entry: Equatable { let id: String; let message: String }
    private let defaults = UserDefaults.standard

    private func storageKey(_ memoId: UUID) -> String { "handledDetections." + memoId.uuidString }

    mutating func entries(for memoId: UUID) -> [Entry] {
        // Always read from UserDefaults to avoid stale caches across instances.
        guard let raw = defaults.array(forKey: storageKey(memoId)) as? [[String: String]] else { return [] }
        return raw.compactMap { dict -> Entry? in
            guard let id = dict["id"], let message = dict["message"] else { return nil }
            return Entry(id: id, message: message)
        }
    }

    mutating func add(_ key: String, message: String, for memoId: UUID) {
        var entries = entries(for: memoId)
        if let idx = entries.firstIndex(where: { $0.id == key }) {
            entries[idx] = Entry(id: key, message: message)
        } else {
            entries.append(Entry(id: key, message: message))
        }
        defaults.set(entries.map { ["id": $0.id, "message": $0.message] }, forKey: storageKey(memoId))
    }

    mutating func remove(_ key: String, for memoId: UUID) {
        var entries = entries(for: memoId)
        if let idx = entries.firstIndex(where: { $0.id == key }) {
            entries.remove(at: idx)
            defaults.set(entries.map { ["id": $0.id, "message": $0.message] }, forKey: storageKey(memoId))
        }
    }

    mutating func messages(for memoId: UUID) -> [Entry] {
        entries(for: memoId)
    }

    mutating func contains(_ key: String, for memoId: UUID) -> Bool {
        entries(for: memoId).contains { $0.id == key }
    }
}
