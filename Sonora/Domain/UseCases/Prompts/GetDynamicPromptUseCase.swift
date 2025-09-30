import Foundation

public protocol GetDynamicPromptUseCaseProtocol: Sendable {
    /// Legacy API: context-aware dynamic prompt
    func execute(userName: String?) async throws -> InterpolatedPrompt?
    /// New API: policy-driven selection with rotation token support
    func next(_ request: SelectPromptRequest) async throws -> NextPromptResponse?
}

public extension GetDynamicPromptUseCaseProtocol {
    /// Default implementation for conformers that don't override `next`.
    /// Wraps the legacy execute() to preserve test doubles.
    func next(_ request: SelectPromptRequest) async throws -> NextPromptResponse? {
        if let p = try await execute(userName: request.userName) {
            return NextPromptResponse(prompt: p, rotationToken: request.rotationToken, source: "dynamic")
        }
        return nil
    }
}

public final class GetDynamicPromptUseCase: GetDynamicPromptUseCaseProtocol, @unchecked Sendable {
    private let catalog: PromptCatalog
    private let usageRepository: PromptUsageRepository
    private let dateProvider: DateProvider
    private let localization: LocalizationProvider
    private let logger: any LoggerProtocol
    private let eventBus: any EventBusProtocol
    private let config: AppConfiguration

    public init(
        catalog: PromptCatalog,
        usageRepository: PromptUsageRepository,
        dateProvider: DateProvider,
        localization: LocalizationProvider,
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol = EventBus.shared,
        config: AppConfiguration = .shared
    ) {
        self.catalog = catalog
        self.usageRepository = usageRepository
        self.dateProvider = dateProvider
        self.localization = localization
        self.logger = logger
        self.eventBus = eventBus
        self.config = config
    }

    public func execute(userName: String?) async throws -> InterpolatedPrompt? {
        // Backwards-compatible: use context-aware policy
        let req = SelectPromptRequest(userName: userName, policy: .contextAware, currentPromptId: nil, rotationToken: nil)
        let res = try await next(req)
        return res?.prompt
    }

    // MARK: - New Selection API

    public func next(_ request: SelectPromptRequest) async throws -> NextPromptResponse? {
        let now = dateProvider.now
        let dayPart = dateProvider.dayPart(for: now)
        let weekPart = dateProvider.weekPart(for: now)
        let cal = dateProvider.calendar
        guard let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: now) else { return nil }

        // Gather catalog candidates
        let all = catalog.allPrompts()
        // Stage counters for telemetry
        var counts: [String: Int] = [:]

        // 1) Base filtering by policy
        var base: [RecordingPrompt]
        switch request.policy {
        case .contextAware:
            base = all.filter { $0.allowedDayParts.contains(dayPart) && $0.allowedWeekParts.contains(weekPart) }
            if base.isEmpty { base = all.filter { $0.allowedDayParts.contains(dayPart) } }
            if base.isEmpty { base = all }
        case .exploration:
            // Start narrow to context, progressively relax to ensure variety
            let ctx = all.filter { $0.allowedDayParts.contains(dayPart) && $0.allowedWeekParts.contains(weekPart) }
            let dayOnly = all.filter { $0.allowedDayParts.contains(dayPart) }
            let any = all
            // Compose base without duplicates, preserving progression priority
            base = []
            base.reserveCapacity(any.count)
            for group in [ctx, dayOnly, any] {
                for p in group where !base.contains(where: { $0.id == p.id }) { base.append(p) }
            }
        }
        counts["base"] = base.count

        // 2) Apply 7-day no-repeat (USED)
        let usedRecently = try await usageRepository.recentlyUsedPromptIds(since: sevenDaysAgo)
        var candidates = base.filter { !usedRecently.contains($0.id) }
        counts["afterUsed"] = candidates.count

        // 3) Apply short cooldown for recently SHOWN
        let cooldownMinutes = max(0, config.promptCooldownMinutes)
        if cooldownMinutes > 0, let shownSince = cal.date(byAdding: .minute, value: -cooldownMinutes, to: now) {
            let shownRecently = try await usageRepository.recentlyShownPromptIds(since: shownSince)
            candidates.removeAll { shownRecently.contains($0.id) }
        }
        counts["afterCooldown"] = candidates.count

        // 4) Exploration: ensure minimum variety by relaxing cooldown as last resort
        if request.policy == .exploration, candidates.count < config.promptMinVarietyTarget {
            // Rebuild from base minus 7-day used, ignoring cooldown
            candidates = base.filter { !usedRecently.contains($0.id) }
            counts["afterVarietyRelax"] = candidates.count
        }

        // Guard no candidates
        if candidates.isEmpty { return nil }

        // 5) Determine order: weight desc, lastUsed asc, stable shuffle (seeded) for .contextAware
        //    For .exploration use a rotation token with a stable order (id+seed hash sort)
        let seed = seedString(now: now, dayPart: dayPart, weekPart: weekPart)

        var chosen: RecordingPrompt?
        var newToken: PromptRotationToken?

        if request.policy == .exploration {
            // Use or create rotation order
            let currentId = request.currentPromptId
            let token = request.rotationToken
            // Validate token against current candidates
            let candidateIds = Set(candidates.map { $0.id })
            let useExisting = token?.candidateIds.allSatisfy { candidateIds.contains($0) } == true && token?.candidateIds.isEmpty == false
            let activeToken: PromptRotationToken
            if useExisting, let t = token {
                activeToken = t
            } else {
                // Build stable shuffled ids for exploration (favor variety across categories)
                let exploreSeed = seed + "|explore"
                let ordered = candidates.sorted { lhs, rhs in
                    stableHash(lhs.id + exploreSeed) < stableHash(rhs.id + exploreSeed)
                }
                activeToken = PromptRotationToken(createdAt: now, candidateIds: ordered.map { $0.id }, nextIndex: 0)
            }

            // Walk rotation, skip current id if provided
            var idx = activeToken.nextIndex
            var attempts = 0
            let total = max(1, activeToken.candidateIds.count)
            while attempts < total {
                let id = activeToken.candidateIds[idx]
                if id != currentId, let p = candidates.first(where: { $0.id == id }) {
                    chosen = p
                    // Advance index for next call
                    let nextIdx = (idx + 1) % total
                    newToken = PromptRotationToken(createdAt: activeToken.createdAt, candidateIds: activeToken.candidateIds, nextIndex: nextIdx)
                    break
                }
                idx = (idx + 1) % total
                attempts += 1
            }
            // Fallback if all were equal to current or not found
            if chosen == nil { chosen = candidates.first; newToken = activeToken.advancing() }
        } else {
            // Context-aware: deterministic priority list
            // Last used times to bias toward least-recently-used when weights tie
            var lastUsedMap: [String: Date] = [:]
            for id in candidates.map({ $0.id }) {
                if let d = try await usageRepository.lastUsedAt(for: id) { lastUsedMap[id] = d }
            }
            let ordered = candidates.sorted { a, b in
                if a.weight != b.weight { return a.weight > b.weight }
                let aLast = lastUsedMap[a.id] ?? .distantPast
                let bLast = lastUsedMap[b.id] ?? .distantPast
                if aLast != bLast { return aLast < bLast }
                return stableHash(a.id + seed) < stableHash(b.id + seed)
            }
            chosen = ordered.first
        }

        guard let picked = chosen else { return nil }

        // 6) Interpolate tokens
        var tokens: [String: String] = [:]
        if let name = request.userName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { tokens["Name"] = name }
        tokens["DayPart"] = localizedDayPart(dayPart, locale: dateProvider.locale)
        tokens["WeekPart"] = localizedWeekPart(weekPart, locale: dateProvider.locale)
        let text = PromptInterpolation.build(key: picked.localizationKey, tokens: tokens, localization: localization, locale: dateProvider.locale)

        // 7) Side effects + telemetry
        try await usageRepository.markShown(promptId: picked.id, at: now)
        let src = (request.policy == .exploration) ? "inspire" : "dynamic"
        var info: [String: Any] = [
            "id": picked.id,
            "category": picked.category.rawValue,
            "dayPart": dayPart.rawValue,
            "weekPart": weekPart.rawValue,
            "policy": (request.policy == .exploration) ? "exploration" : "contextAware"
        ]
        info.merge(counts.mapValues { $0 as Any }) { _, new in new }
        logger.info("Prompt shown", category: .useCase, context: LogContext(additionalInfo: info))
        await MainActor.run {
            eventBus.publish(.promptShown(id: picked.id, category: picked.category.rawValue, dayPart: dayPart.rawValue, weekPart: weekPart.rawValue, source: src))
        }

        let prompt = InterpolatedPrompt(id: picked.id, text: text, category: picked.category, emotionalDepth: picked.emotionalDepth, dayPart: dayPart, weekPart: weekPart)
        return NextPromptResponse(prompt: prompt, rotationToken: newToken, source: src)
    }

    // MARK: - Helpers

    private func seedString(now: Date, dayPart: DayPart, weekPart: WeekPart) -> String {
        let dayOfYear = dateProvider.calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        return "\(dayOfYear)|\(dayPart.rawValue)|\(weekPart.rawValue)"
    }

    private func stableHash(_ s: String) -> UInt64 {
        // djb2
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
