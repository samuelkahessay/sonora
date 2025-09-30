import Foundation

// MARK: - AppConfiguration Section Models and Loaders

// Helper for local parsing in this file only.
fileprivate enum _AppConfigParseHelper {
    static func requireURL(_ s: String) -> URL {
        guard let url = URL(string: s) else { preconditionFailure("Invalid URL constant: \(s)") }
        return url
    }
}

// MARK: API
struct APIConfig: Sendable {
    let baseURL: URL
    let analysisTimeout: TimeInterval
    let transcriptionTimeout: TimeInterval
    let preferredTranscriptionLanguage: String?
    let healthTimeout: TimeInterval

    static func defaults(build: BuildConfiguration) -> APIConfig {
        // Build-specific defaults
        let base = _AppConfigParseHelper.requireURL("https://sonora.fly.dev")
        let analysis: TimeInterval
        let transcription: TimeInterval
        let health: TimeInterval

        switch (build.buildType, build.distributionType) {
        case (.debug, .development):
            analysis = 30.0
            transcription = 180.0
            health = 10.0
        case (.testing, _):
            analysis = 15.0
            transcription = 120.0
            health = 8.0
        case (.release, .testFlight):
            analysis = 15.0
            transcription = 120.0
            health = 6.0
        case (.release, .appStore):
            analysis = 12.0
            transcription = 120.0
            health = 5.0
        default:
            analysis = 12.0
            transcription = 120.0
            health = 5.0
        }

        return APIConfig(
            baseURL: base,
            analysisTimeout: analysis,
            transcriptionTimeout: transcription,
            preferredTranscriptionLanguage: nil,
            healthTimeout: health
        )
    }

    func withOverrides(env: [String: String]) -> APIConfig {
        var c = self
        if let apiURLString = env["SONORA_API_URL"], let url = URL(string: apiURLString) {
            c = APIConfig(
                baseURL: url,
                analysisTimeout: c.analysisTimeout,
                transcriptionTimeout: c.transcriptionTimeout,
                preferredTranscriptionLanguage: c.preferredTranscriptionLanguage,
                healthTimeout: c.healthTimeout
            )
            print("🔧 AppConfiguration: API URL overridden to \(url.absoluteString)")
        }
        if let timeoutString = env["SONORA_ANALYSIS_TIMEOUT"], let timeout = TimeInterval(timeoutString) {
            c = APIConfig(
                baseURL: c.baseURL,
                analysisTimeout: timeout,
                transcriptionTimeout: c.transcriptionTimeout,
                preferredTranscriptionLanguage: c.preferredTranscriptionLanguage,
                healthTimeout: c.healthTimeout
            )
            print("🔧 AppConfiguration: Analysis timeout overridden to \(timeout)s")
        }
        if let timeoutString = env["SONORA_TRANSCRIPTION_TIMEOUT"], let timeout = TimeInterval(timeoutString) {
            c = APIConfig(
                baseURL: c.baseURL,
                analysisTimeout: c.analysisTimeout,
                transcriptionTimeout: timeout,
                preferredTranscriptionLanguage: c.preferredTranscriptionLanguage,
                healthTimeout: c.healthTimeout
            )
            print("🔧 AppConfiguration: Transcription timeout overridden to \(timeout)s")
        }
        if let lang = env["SONORA_TRANSCRIPTION_LANGUAGE"], !lang.isEmpty {
            c = APIConfig(
                baseURL: c.baseURL,
                analysisTimeout: c.analysisTimeout,
                transcriptionTimeout: c.transcriptionTimeout,
                preferredTranscriptionLanguage: lang.lowercased(),
                healthTimeout: c.healthTimeout
            )
            print("🔧 AppConfiguration: Preferred transcription language overridden to \(lang)")
        }
        if let timeoutString = env["SONORA_HEALTH_TIMEOUT"], let timeout = TimeInterval(timeoutString) {
            c = APIConfig(
                baseURL: c.baseURL,
                analysisTimeout: c.analysisTimeout,
                transcriptionTimeout: c.transcriptionTimeout,
                preferredTranscriptionLanguage: c.preferredTranscriptionLanguage,
                healthTimeout: timeout
            )
            print("🔧 AppConfiguration: Health check timeout overridden to \(timeout)s")
        }
        return c
    }
}

// MARK: Recording
struct RecordingConfig: Sendable {
    let maxRecordingDuration: TimeInterval
    let maxRecordingFileSize: Int64
    let recordingQuality: Float
    let audioSampleRate: Double
    let audioChannels: Int
    let audioBitRate: Int
    let voiceOptimizedQuality: Float
    let enableAdaptiveAudioQuality: Bool

    static func defaults(build: BuildConfiguration) -> RecordingConfig {
        let maxDuration: TimeInterval = 180.0
        let fileSize: Int64 = build.isDebug ? 100 * 1_024 * 1_024 : 50 * 1_024 * 1_024
        let quality: Float = build.isDebug ? 1.0 : 0.8
        let sampleRate: Double = 22_050.0
        let channels: Int = 1
        let bitRate: Int = 64_000
        let voiceQuality: Float = 0.7
        let adaptive: Bool = true

        return RecordingConfig(
            maxRecordingDuration: maxDuration,
            maxRecordingFileSize: fileSize,
            recordingQuality: quality,
            audioSampleRate: sampleRate,
            audioChannels: channels,
            audioBitRate: bitRate,
            voiceOptimizedQuality: voiceQuality,
            enableAdaptiveAudioQuality: adaptive
        )
    }

    func withOverrides(env: [String: String]) -> RecordingConfig {
        var c = self
        if let s = env["SONORA_MAX_RECORDING_DURATION"], let v = TimeInterval(s) {
            c = c.copy(maxRecordingDuration: v)
            print("🔧 AppConfiguration: Max recording duration overridden to \(v)s")
        }
        if let s = env["SONORA_MAX_FILE_SIZE"], let v = Int64(s) {
            c = c.copy(maxRecordingFileSize: v)
            print("🔧 AppConfiguration: Max file size overridden to \(v) bytes")
        }
        if let s = env["SONORA_RECORDING_QUALITY"], let v = Float(s) {
            let clamped = max(0.0, min(1.0, v))
            c = c.copy(recordingQuality: clamped)
            print("🔧 AppConfiguration: Recording quality overridden to \(clamped)")
        }
        if let s = env["SONORA_SAMPLE_RATE"], let v = Double(s) {
            c = c.copy(audioSampleRate: v)
            print("🔧 AppConfiguration: Audio sample rate overridden to \(v)")
        }
        if let s = env["SONORA_AUDIO_CHANNELS"], let v = Int(s) {
            let clamped = max(1, min(2, v))
            c = c.copy(audioChannels: clamped)
            print("🔧 AppConfiguration: Audio channels overridden to \(clamped)")
        }
        if let s = env["SONORA_AUDIO_BITRATE"], let v = Int(s) {
            let clamped = max(32_000, min(320_000, v))
            c = c.copy(audioBitRate: clamped)
            print("🔧 AppConfiguration: Audio bit rate overridden to \(clamped)")
        }
        if let s = env["SONORA_VOICE_QUALITY"], let v = Float(s) {
            let clamped = max(0.0, min(1.0, v))
            c = c.copy(voiceOptimizedQuality: clamped)
            print("🔧 AppConfiguration: Voice quality overridden to \(clamped)")
        }
        if let s = env["SONORA_ADAPTIVE_QUALITY"], let v = Bool(s) {
            c = c.copy(enableAdaptiveAudioQuality: v)
            print("🔧 AppConfiguration: Adaptive quality overridden to \(v)")
        }
        return c
    }

    private func copy(
        maxRecordingDuration: TimeInterval? = nil,
        maxRecordingFileSize: Int64? = nil,
        recordingQuality: Float? = nil,
        audioSampleRate: Double? = nil,
        audioChannels: Int? = nil,
        audioBitRate: Int? = nil,
        voiceOptimizedQuality: Float? = nil,
        enableAdaptiveAudioQuality: Bool? = nil
    ) -> RecordingConfig {
        RecordingConfig(
            maxRecordingDuration: maxRecordingDuration ?? self.maxRecordingDuration,
            maxRecordingFileSize: maxRecordingFileSize ?? self.maxRecordingFileSize,
            recordingQuality: recordingQuality ?? self.recordingQuality,
            audioSampleRate: audioSampleRate ?? self.audioSampleRate,
            audioChannels: audioChannels ?? self.audioChannels,
            audioBitRate: audioBitRate ?? self.audioBitRate,
            voiceOptimizedQuality: voiceOptimizedQuality ?? self.voiceOptimizedQuality,
            enableAdaptiveAudioQuality: enableAdaptiveAudioQuality ?? self.enableAdaptiveAudioQuality
        )
    }
}

// MARK: Network
struct NetworkConfig: Sendable {
    let maxNetworkRetries: Int
    let retryBaseDelay: TimeInterval
    let maxConcurrentNetworkOperations: Int
    let resourceTimeoutInterval: TimeInterval

    static func defaults(build: BuildConfiguration) -> NetworkConfig {
        if build.isDebug {
            return NetworkConfig(
                maxNetworkRetries: 5,
                retryBaseDelay: 2.0,
                maxConcurrentNetworkOperations: 2,
                resourceTimeoutInterval: 60.0
            )
        } else {
            return NetworkConfig(
                maxNetworkRetries: 3,
                retryBaseDelay: 1.0,
                maxConcurrentNetworkOperations: 3,
                resourceTimeoutInterval: 30.0
            )
        }
    }

    func withOverrides(env: [String: String]) -> NetworkConfig {
        var c = self
        if let s = env["SONORA_MAX_RETRIES"], let v = Int(s) { c = c.copy(maxNetworkRetries: max(0, v)); print("🔧 AppConfiguration: Max retries overridden to \(max(0, v))") }
        if let s = env["SONORA_RETRY_DELAY"], let v = TimeInterval(s) { c = c.copy(retryBaseDelay: max(0.1, v)); print("🔧 AppConfiguration: Retry delay overridden to \(max(0.1, v))s") }
        if let s = env["SONORA_MAX_CONCURRENT_OPERATIONS"], let v = Int(s) { c = c.copy(maxConcurrentNetworkOperations: max(1, v)); print("🔧 AppConfiguration: Max concurrent operations overridden to \(max(1, v))") }
        if let s = env["SONORA_RESOURCE_TIMEOUT"], let v = TimeInterval(s) { c = c.copy(resourceTimeoutInterval: v); print("🔧 AppConfiguration: Resource timeout overridden to \(v)s") }
        return c
    }

    private func copy(
        maxNetworkRetries: Int? = nil,
        retryBaseDelay: TimeInterval? = nil,
        maxConcurrentNetworkOperations: Int? = nil,
        resourceTimeoutInterval: TimeInterval? = nil
    ) -> NetworkConfig {
        NetworkConfig(
            maxNetworkRetries: maxNetworkRetries ?? self.maxNetworkRetries,
            retryBaseDelay: retryBaseDelay ?? self.retryBaseDelay,
            maxConcurrentNetworkOperations: maxConcurrentNetworkOperations ?? self.maxConcurrentNetworkOperations,
            resourceTimeoutInterval: resourceTimeoutInterval ?? self.resourceTimeoutInterval
        )
    }
}

// MARK: Analysis
struct AnalysisConfig: Sendable {
    let distillAnalysisTimeout: TimeInterval
    let contentAnalysisTimeout: TimeInterval
    let themesAnalysisTimeout: TimeInterval
    let todosAnalysisTimeout: TimeInterval
    let minimumTranscriptLength: Int
    let maximumTranscriptLength: Int

    static func defaults(build: BuildConfiguration) -> AnalysisConfig {
        if build.isDebug {
            return AnalysisConfig(
                distillAnalysisTimeout: 35.0,
                contentAnalysisTimeout: 35.0,
                themesAnalysisTimeout: 30.0,
                todosAnalysisTimeout: 28.0,
                minimumTranscriptLength: 10,
                maximumTranscriptLength: 50_000
            )
        } else {
            return AnalysisConfig(
                distillAnalysisTimeout: 35.0,
                contentAnalysisTimeout: 20.0,
                themesAnalysisTimeout: 18.0,
                todosAnalysisTimeout: 16.0,
                minimumTranscriptLength: 10,
                maximumTranscriptLength: 50_000
            )
        }
    }

    func withOverrides(env: [String: String]) -> AnalysisConfig {
        var c = self
        if let s = env["SONORA_DISTILL_TIMEOUT"], let v = TimeInterval(s) { c = c.copy(distillAnalysisTimeout: v); print("🔧 AppConfiguration: Distill timeout overridden to \(v)s") }
        if let s = env["SONORA_CONTENT_TIMEOUT"], let v = TimeInterval(s) { c = c.copy(contentAnalysisTimeout: v); print("🔧 AppConfiguration: Content timeout overridden to \(v)s") }
        if let s = env["SONORA_THEMES_TIMEOUT"], let v = TimeInterval(s) { c = c.copy(themesAnalysisTimeout: v); print("🔧 AppConfiguration: Themes timeout overridden to \(v)s") }
        if let s = env["SONORA_TODOS_TIMEOUT"], let v = TimeInterval(s) { c = c.copy(todosAnalysisTimeout: v); print("🔧 AppConfiguration: Todos timeout overridden to \(v)s") }
        if let s = env["SONORA_MIN_TRANSCRIPT_LENGTH"], let v = Int(s) { c = c.copy(minimumTranscriptLength: max(1, v)); print("🔧 AppConfiguration: Min transcript length overridden to \(max(1, v))") }
        if let s = env["SONORA_MAX_TRANSCRIPT_LENGTH"], let v = Int(s) { c = c.copy(maximumTranscriptLength: max(self.minimumTranscriptLength, v)); print("🔧 AppConfiguration: Max transcript length overridden to \(max(self.minimumTranscriptLength, v))") }
        return c
    }

    private func copy(
        distillAnalysisTimeout: TimeInterval? = nil,
        contentAnalysisTimeout: TimeInterval? = nil,
        themesAnalysisTimeout: TimeInterval? = nil,
        todosAnalysisTimeout: TimeInterval? = nil,
        minimumTranscriptLength: Int? = nil,
        maximumTranscriptLength: Int? = nil
    ) -> AnalysisConfig {
        AnalysisConfig(
            distillAnalysisTimeout: distillAnalysisTimeout ?? self.distillAnalysisTimeout,
            contentAnalysisTimeout: contentAnalysisTimeout ?? self.contentAnalysisTimeout,
            themesAnalysisTimeout: themesAnalysisTimeout ?? self.themesAnalysisTimeout,
            todosAnalysisTimeout: todosAnalysisTimeout ?? self.todosAnalysisTimeout,
            minimumTranscriptLength: minimumTranscriptLength ?? self.minimumTranscriptLength,
            maximumTranscriptLength: maximumTranscriptLength ?? self.maximumTranscriptLength
        )
    }
}

// MARK: Live Activity
struct LiveActivityConfig: Sendable {
    let liveActivityUpdateInterval: TimeInterval
    let liveActivityGracePeriod: TimeInterval
    let liveActivityShowDetailedProgress: Bool
    let backgroundRefreshRate: TimeInterval

    static func defaults(build: BuildConfiguration) -> LiveActivityConfig {
        if build.isDebug {
            return LiveActivityConfig(
                liveActivityUpdateInterval: 1.0,
                liveActivityGracePeriod: 60.0,
                liveActivityShowDetailedProgress: true,
                backgroundRefreshRate: 2.0
            )
        } else {
            return LiveActivityConfig(
                liveActivityUpdateInterval: 2.0,
                liveActivityGracePeriod: 30.0,
                liveActivityShowDetailedProgress: true,
                backgroundRefreshRate: 5.0
            )
        }
    }

    func withOverrides(env: [String: String]) -> LiveActivityConfig {
        var c = self
        if let s = env["SONORA_LIVE_ACTIVITY_UPDATE_INTERVAL"], let v = TimeInterval(s) { c = c.copy(liveActivityUpdateInterval: max(0.5, v)); print("🔧 AppConfiguration: Live Activity update interval overridden to \(max(0.5, v))s") }
        if let s = env["SONORA_LIVE_ACTIVITY_GRACE_PERIOD"], let v = TimeInterval(s) { c = c.copy(liveActivityGracePeriod: max(0.0, v)); print("🔧 AppConfiguration: Live Activity grace period overridden to \(max(0.0, v))s") }
        if let s = env["SONORA_LIVE_ACTIVITY_DETAILED_PROGRESS"], let v = Bool(s) { c = c.copy(liveActivityShowDetailedProgress: v); print("🔧 AppConfiguration: Live Activity detailed progress overridden to \(v)") }
        if let s = env["SONORA_BACKGROUND_REFRESH_RATE"], let v = TimeInterval(s) { c = c.copy(backgroundRefreshRate: max(1.0, v)); print("🔧 AppConfiguration: Background refresh rate overridden to \(max(1.0, v))s") }
        return c
    }

    private func copy(
        liveActivityUpdateInterval: TimeInterval? = nil,
        liveActivityGracePeriod: TimeInterval? = nil,
        liveActivityShowDetailedProgress: Bool? = nil,
        backgroundRefreshRate: TimeInterval? = nil
    ) -> LiveActivityConfig {
        LiveActivityConfig(
            liveActivityUpdateInterval: liveActivityUpdateInterval ?? self.liveActivityUpdateInterval,
            liveActivityGracePeriod: liveActivityGracePeriod ?? self.liveActivityGracePeriod,
            liveActivityShowDetailedProgress: liveActivityShowDetailedProgress ?? self.liveActivityShowDetailedProgress,
            backgroundRefreshRate: backgroundRefreshRate ?? self.backgroundRefreshRate
        )
    }
}

// MARK: Cache
struct CacheConfig: Sendable {
    let memoryCacheMaxSize: Int
    let analysisCacheTTL: TimeInterval
    let diskCacheEnabled: Bool

    static func defaults(build: BuildConfiguration) -> CacheConfig {
        if build.isDebug {
            return CacheConfig(
                memoryCacheMaxSize: 100,
                analysisCacheTTL: 43_200.0, // 12h
                diskCacheEnabled: true
            )
        } else {
            return CacheConfig(
                memoryCacheMaxSize: 50,
                analysisCacheTTL: 86_400.0, // 24h
                diskCacheEnabled: true
            )
        }
    }

    func withOverrides(env: [String: String]) -> CacheConfig {
        var c = self
        if let s = env["SONORA_MEMORY_CACHE_SIZE"], let v = Int(s) { c = c.copy(memoryCacheMaxSize: max(1, v)); print("🔧 AppConfiguration: Memory cache size overridden to \(max(1, v))") }
        if let s = env["SONORA_CACHE_TTL"], let v = TimeInterval(s) { c = c.copy(analysisCacheTTL: max(60.0, v)); print("🔧 AppConfiguration: Cache TTL overridden to \(max(60.0, v))s") }
        if let s = env["SONORA_DISK_CACHE_ENABLED"], let v = Bool(s) { c = c.copy(diskCacheEnabled: v); print("🔧 AppConfiguration: Disk cache overridden to \(v)") }
        return c
    }

    private func copy(
        memoryCacheMaxSize: Int? = nil,
        analysisCacheTTL: TimeInterval? = nil,
        diskCacheEnabled: Bool? = nil
    ) -> CacheConfig {
        CacheConfig(
            memoryCacheMaxSize: memoryCacheMaxSize ?? self.memoryCacheMaxSize,
            analysisCacheTTL: analysisCacheTTL ?? self.analysisCacheTTL,
            diskCacheEnabled: diskCacheEnabled ?? self.diskCacheEnabled
        )
    }
}

// MARK: Prompts
struct PromptsConfig: Sendable {
    let promptCooldownMinutes: Int
    let promptMinVarietyTarget: Int

    static func defaults() -> PromptsConfig {
        PromptsConfig(promptCooldownMinutes: 3, promptMinVarietyTarget: 10)
    }

    func withOverrides(env: [String: String]) -> PromptsConfig {
        var c = self
        if let s = env["SONORA_PROMPT_COOLDOWN_MINUTES"], let v = Int(s) { c = c.copy(promptCooldownMinutes: max(0, v)); print("🔧 AppConfiguration: Prompt cooldown overridden to \(max(0, v)) min") }
        if let s = env["SONORA_PROMPT_MIN_VARIETY"], let v = Int(s) { c = c.copy(promptMinVarietyTarget: max(1, v)); print("🔧 AppConfiguration: Prompt min variety target overridden to \(max(1, v))") }
        return c
    }

    private func copy(promptCooldownMinutes: Int? = nil, promptMinVarietyTarget: Int? = nil) -> PromptsConfig {
        PromptsConfig(
            promptCooldownMinutes: promptCooldownMinutes ?? self.promptCooldownMinutes,
            promptMinVarietyTarget: promptMinVarietyTarget ?? self.promptMinVarietyTarget
        )
    }
}

