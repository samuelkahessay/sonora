import Foundation

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

    private var cache: [UUID: [Entry]] = [:]
    private let defaults = UserDefaults.standard

    private func storageKey(_ memoId: UUID) -> String { "handledDetections." + memoId.uuidString }

    mutating func entries(for memoId: UUID) -> [Entry] {
        if let cached = cache[memoId] { return cached }
        guard let raw = defaults.array(forKey: storageKey(memoId)) as? [[String: String]] else {
            cache[memoId] = []
            return []
        }
        let entries = raw.compactMap { dict -> Entry? in
            guard let id = dict["id"], let message = dict["message"] else { return nil }
            return Entry(id: id, message: message)
        }
        cache[memoId] = entries
        return entries
    }

    mutating func add(_ key: String, message: String, for memoId: UUID) {
        var entries = entries(for: memoId)
        if let idx = entries.firstIndex(where: { $0.id == key }) {
            entries[idx] = Entry(id: key, message: message)
        } else {
            entries.append(Entry(id: key, message: message))
        }
        cache[memoId] = entries
        defaults.set(entries.map { ["id": $0.id, "message": $0.message] }, forKey: storageKey(memoId))
    }

    mutating func remove(_ key: String, for memoId: UUID) {
        var entries = entries(for: memoId)
        if let idx = entries.firstIndex(where: { $0.id == key }) {
            entries.remove(at: idx)
            cache[memoId] = entries
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
