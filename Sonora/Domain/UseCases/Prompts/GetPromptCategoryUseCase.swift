import Foundation

public protocol GetPromptCategoryUseCaseProtocol: Sendable {
    func execute(category: PromptCategory, userName: String?) async throws -> [InterpolatedPrompt]
    @MainActor
    func setFavorite(promptId: String, isFavorite: Bool) throws
    @MainActor
    func markUsed(promptId: String) throws
}

public final class GetPromptCategoryUseCase: GetPromptCategoryUseCaseProtocol, @unchecked Sendable {
    private let catalog: PromptCatalog
    private let usageRepository: PromptUsageRepository
    private let dateProvider: DateProvider
    private let localization: LocalizationProvider
    private let logger: any LoggerProtocol
    private let eventBus: any EventBusProtocol

    public init(
        catalog: PromptCatalog,
        usageRepository: PromptUsageRepository,
        dateProvider: DateProvider,
        localization: LocalizationProvider,
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol = EventBus.shared
    ) {
        self.catalog = catalog
        self.usageRepository = usageRepository
        self.dateProvider = dateProvider
        self.localization = localization
        self.logger = logger
        self.eventBus = eventBus
    }

    public func execute(category: PromptCategory, userName: String?) async throws -> [InterpolatedPrompt] {
        let now = dateProvider.now
        let dayPart = dateProvider.dayPart(for: now)
        let weekPart = dateProvider.weekPart(for: now)
        let cal = dateProvider.calendar
        let since = cal.date(byAdding: .day, value: -7, to: now) ?? now

        var candidates = catalog
            .prompts(in: category)
            .filter { $0.allowedDayParts.contains(dayPart) && $0.allowedWeekParts.contains(weekPart) }
        if candidates.isEmpty {
            candidates = catalog.prompts(in: category)
        }

        let recent = try await usageRepository.recentlyUsedPromptIds(since: since)
        candidates.removeAll { recent.contains($0.id) }

        let favs = try await usageRepository.favorites()
        var lastUsedMap: [String: Date] = [:]
        for id in candidates.map({ $0.id }) {
            if let d = try await usageRepository.lastUsedAt(for: id) { lastUsedMap[id] = d }
        }
        let seed = "\(dateProvider.calendar.ordinality(of: .day, in: .year, for: now) ?? 0)|\(category.rawValue)"
        let sorted = candidates.sorted { a, b in
            let aFav = favs.contains(a.id)
            let bFav = favs.contains(b.id)
            if aFav != bFav { return aFav }
            let aLast = lastUsedMap[a.id] ?? .distantPast
            let bLast = lastUsedMap[b.id] ?? .distantPast
            if aLast != bLast { return aLast < bLast }
            if a.weight != b.weight { return a.weight > b.weight }
            return stableHash(a.id + seed) < stableHash(b.id + seed)
        }

        var tokens: [String: String] = [:]
        if let name = userName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { tokens["Name"] = name }
        tokens["DayPart"] = localizedDayPart(dayPart, locale: dateProvider.locale)
        tokens["WeekPart"] = localizedWeekPart(weekPart, locale: dateProvider.locale)

        return sorted.map { p in
            let text = PromptInterpolation.build(key: p.localizationKey, tokens: tokens, localization: localization, locale: dateProvider.locale)
            return InterpolatedPrompt(id: p.id, text: text, category: p.category, emotionalDepth: p.emotionalDepth, dayPart: dayPart, weekPart: weekPart)
        }
    }

    @MainActor
    public func setFavorite(promptId: String, isFavorite: Bool) throws {
        try usageRepository.setFavorite(promptId: promptId, isFavorite: isFavorite, at: dateProvider.now)
        logger.debug("Prompt favorite toggled", category: .useCase, context: LogContext(additionalInfo: ["id": promptId, "isFavorite": isFavorite]))
        eventBus.publish(.promptFavoritedToggled(id: promptId, isFavorite: isFavorite))
    }

    @MainActor
    public func markUsed(promptId: String) throws {
        try usageRepository.markUsed(promptId: promptId, at: dateProvider.now)
        let dayPart = dateProvider.dayPart(for: dateProvider.now).rawValue
        let weekPart = dateProvider.weekPart(for: dateProvider.now).rawValue
        logger.info("Prompt used", category: .useCase, context: LogContext(additionalInfo: ["id": promptId, "dayPart": dayPart, "weekPart": weekPart]))
        // Category lookup for logging/event: resolve from catalog (best-effort)
        let cat = catalog.allPrompts().first { $0.id == promptId }?.category.rawValue ?? "unknown"
        eventBus.publish(.promptUsed(id: promptId, category: cat, dayPart: dayPart, weekPart: weekPart, action: "accept"))
    }

    // MARK: - Helpers
    private func stableHash(_ s: String) -> UInt64 {
        var hash: UInt64 = 5_381
        for byte in s.utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(byte) }
        return hash
    }

    private func localizedDayPart(_ part: DayPart, locale: Locale) -> String {
        switch part {
        case .morning: return localization.localizedString("daypart.morning", locale: locale)
        case .afternoon: return localization.localizedString("daypart.afternoon", locale: locale)
        case .evening: return localization.localizedString("daypart.evening", locale: locale)
        case .night: return localization.localizedString("daypart.night", locale: locale)
        }
    }

    private func localizedWeekPart(_ part: WeekPart, locale: Locale) -> String {
        switch part {
        case .startOfWeek: return localization.localizedString("weekpart.start", locale: locale)
        case .midWeek: return localization.localizedString("weekpart.mid", locale: locale)
        case .endOfWeek: return localization.localizedString("weekpart.end", locale: locale)
        }
    }
}
