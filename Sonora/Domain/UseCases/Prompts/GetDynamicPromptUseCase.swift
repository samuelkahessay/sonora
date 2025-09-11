import Foundation

public protocol GetDynamicPromptUseCaseProtocol: Sendable {
    func execute(userName: String?) async throws -> InterpolatedPrompt?
}

public final class GetDynamicPromptUseCase: GetDynamicPromptUseCaseProtocol, @unchecked Sendable {
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

    public func execute(userName: String?) async throws -> InterpolatedPrompt? {
        let now = dateProvider.now
        let dayPart = dateProvider.dayPart(for: now)
        let weekPart = dateProvider.weekPart(for: now)
        let cal = dateProvider.calendar
        guard let since = cal.date(byAdding: .day, value: -7, to: now) else { return nil }

        // Candidate set filtered by context
        var candidates = catalog.allPrompts().filter {
            $0.allowedDayParts.contains(dayPart) && $0.allowedWeekParts.contains(weekPart)
        }
        if candidates.isEmpty {
            candidates = catalog.allPrompts().filter { $0.allowedDayParts.contains(dayPart) }
        }
        if candidates.isEmpty { candidates = catalog.allPrompts() }

        // Apply 7-day no-repeat rule
        let recent = try await usageRepository.recentlyUsedPromptIds(since: since)
        candidates.removeAll { recent.contains($0.id) }
        if candidates.isEmpty { return nil }

        // Sort by weight desc, lastUsedAt asc, then stable seeded tie-breaker
        let seed = seedString(now: now, dayPart: dayPart, weekPart: weekPart)
        var lastUsedMap: [String: Date] = [:]
        for id in candidates.map({ $0.id }) {
            if let d = try await usageRepository.lastUsedAt(for: id) { lastUsedMap[id] = d }
        }
        candidates.sort { a, b in
            if a.weight != b.weight { return a.weight > b.weight }
            let aLast = lastUsedMap[a.id] ?? .distantPast
            let bLast = lastUsedMap[b.id] ?? .distantPast
            if aLast != bLast { return aLast < bLast }
            return stableHash(a.id + seed) < stableHash(b.id + seed)
        }

        guard let chosen = candidates.first else { return nil }

        // Build tokens
        var tokens: [String: String] = [:]
        if let name = userName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tokens["Name"] = name
        }
        tokens["DayPart"] = localizedDayPart(dayPart, locale: dateProvider.locale)
        tokens["WeekPart"] = localizedWeekPart(weekPart, locale: dateProvider.locale)

        let text = PromptInterpolation.build(
            key: chosen.localizationKey,
            tokens: tokens,
            localization: localization,
            locale: dateProvider.locale
        )

        // Side effects
        try await usageRepository.markShown(promptId: chosen.id, at: now)
        let info: [String: Any] = [
            "id": chosen.id,
            "category": chosen.category.rawValue,
            "dayPart": dayPart.rawValue,
            "weekPart": weekPart.rawValue,
        ]
        logger.info("Prompt shown", category: .useCase, context: LogContext(additionalInfo: info))
        await MainActor.run {
            eventBus.publish(.promptShown(id: chosen.id, category: chosen.category.rawValue, dayPart: dayPart.rawValue, weekPart: weekPart.rawValue, source: "dynamic"))
        }

        return InterpolatedPrompt(
            id: chosen.id,
            text: text,
            category: chosen.category,
            emotionalDepth: chosen.emotionalDepth,
            dayPart: dayPart,
            weekPart: weekPart
        )
    }

    // MARK: - Helpers

    private func seedString(now: Date, dayPart: DayPart, weekPart: WeekPart) -> String {
        let dayOfYear = dateProvider.calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        return "\(dayOfYear)|\(dayPart.rawValue)|\(weekPart.rawValue)"
    }

    private func stableHash(_ s: String) -> UInt64 {
        // djb2
        var hash: UInt64 = 5381
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
