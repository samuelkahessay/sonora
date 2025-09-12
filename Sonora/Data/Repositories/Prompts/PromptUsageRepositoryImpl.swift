import Foundation
import SwiftData

@MainActor
final class PromptUsageRepositoryImpl: PromptUsageRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    private func fetchRecord(for promptId: String) -> PromptUsageRecord? {
        let descriptor = FetchDescriptor<PromptUsageRecord>(predicate: #Predicate { $0.promptId == promptId })
        return (try? context.fetch(descriptor))?.first
    }

    private func upsertRecord(for promptId: String) -> PromptUsageRecord {
        if let existing = fetchRecord(for: promptId) { return existing }
        let rec = PromptUsageRecord(promptId: promptId)
        context.insert(rec)
        return rec
    }

    func markShown(promptId: String, at date: Date) throws {
        let rec = upsertRecord(for: promptId)
        rec.lastShownAt = date
        rec.updatedAt = date
        try context.save()
    }

    func markUsed(promptId: String, at date: Date) throws {
        let rec = upsertRecord(for: promptId)
        rec.lastUsedAt = date
        rec.useCount = max(0, rec.useCount) + 1
        rec.updatedAt = date
        try context.save()
    }

    func setFavorite(promptId: String, isFavorite: Bool, at date: Date) throws {
        let rec = upsertRecord(for: promptId)
        rec.isFavorite = isFavorite
        rec.updatedAt = date
        try context.save()
    }

    func favorites() throws -> Set<String> {
        let descriptor = FetchDescriptor<PromptUsageRecord>(predicate: #Predicate { $0.isFavorite == true })
        let results = try context.fetch(descriptor)
        return Set(results.map { $0.promptId })
    }

    func recentlyUsedPromptIds(since date: Date) throws -> Set<String> {
        // SwiftData predicate DSL has limited optional support; fetch non-nil and filter in-memory
        let descriptor = FetchDescriptor<PromptUsageRecord>(predicate: #Predicate { $0.lastUsedAt != nil })
        let results = try context.fetch(descriptor)
        let filtered = results.filter { rec in
            if let last = rec.lastUsedAt { return last >= date }
            return false
        }
        return Set(filtered.map { $0.promptId })
    }

    func lastUsedAt(for promptId: String) throws -> Date? {
        return fetchRecord(for: promptId)?.lastUsedAt
    }

    func recentlyShownPromptIds(since date: Date) throws -> Set<String> {
        let descriptor = FetchDescriptor<PromptUsageRecord>(predicate: #Predicate { $0.lastShownAt != nil })
        let results = try context.fetch(descriptor)
        let filtered = results.filter { rec in
            if let last = rec.lastShownAt { return last >= date }
            return false
        }
        return Set(filtered.map { $0.promptId })
    }

    func lastShownAt(for promptId: String) throws -> Date? {
        return fetchRecord(for: promptId)?.lastShownAt
    }
}
