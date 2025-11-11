import Combine
import Foundation

/// Centralized application configuration management
/// Provides type-safe access to all app configuration values with environment variable support
public final class AppConfiguration: ObservableObject {

    // MARK: - Singleton

    public static let shared = AppConfiguration()

    private init() {
        // Load configuration values during initialization
        loadConfiguration()
    }

    // MARK: - Build Configuration Dependency

    private var buildConfig: BuildConfiguration {
        BuildConfiguration.shared
    }

    private static func requireURL(_ s: String) -> URL {
        guard let url = URL(string: s) else { preconditionFailure("Invalid URL constant: \(s)") }
        return url
    }

    // MARK: - API Configuration

    /// Base URL for the Sonora API
    /// Can be overridden with SONORA_API_URL environment variable
    public private(set) var apiBaseURL: URL = {
        guard let url = URL(string: "https://sonora.fly.dev") else {
            preconditionFailure("Invalid default API base URL")
        }
        return url
    }()

    /// API request timeout for analysis operations (in seconds)
    /// Can be overridden with SONORA_ANALYSIS_TIMEOUT environment variable
    public private(set) var analysisTimeoutInterval: TimeInterval = 12.0

    /// API request timeout for transcription operations (in seconds)
    /// Can be overridden with SONORA_TRANSCRIPTION_TIMEOUT environment variable
    public private(set) var transcriptionTimeoutInterval: TimeInterval = 120.0

    /// Preferred transcription language hint (ISO 639-1) or nil for Auto
    /// Can be overridden with SONORA_TRANSCRIPTION_LANGUAGE environment variable
    public private(set) var preferredTranscriptionLanguage: String?

    /// API request timeout for health check operations (in seconds)
    /// Can be overridden with SONORA_HEALTH_TIMEOUT environment variable
    public private(set) var healthCheckTimeoutInterval: TimeInterval = 5.0

    // MARK: - Recording Configuration

    /// Maximum recording duration in seconds (legacy parameter)
    /// Can be overridden with SONORA_MAX_RECORDING_DURATION environment variable
    /// Note: Not used to enforce per-session caps anymore; daily quota is enforced at the domain level.
    public private(set) var maxRecordingDuration: TimeInterval = 180.0

    /// Maximum file size for recordings in bytes (50MB default)
    /// Can be overridden with SONORA_MAX_FILE_SIZE environment variable
    public private(set) var maxRecordingFileSize: Int64 = 50 * 1_024 * 1_024

    /// Recording quality setting (0.0 to 1.0, where 1.0 is highest quality)
    /// Can be overridden with SONORA_RECORDING_QUALITY environment variable
    public private(set) var recordingQuality: Float = 0.8

    /// Audio format for recordings
    public let recordingFormat: String = "m4a"

    /// Sample rate for audio recordings
    /// Can be overridden with SONORA_SAMPLE_RATE environment variable
    /// Voice-optimized default: 22050 Hz (perfect for voice content)
    public private(set) var audioSampleRate: Double = 22_050.0

    /// Number of audio channels (1 = mono, 2 = stereo)
    /// Can be overridden with SONORA_AUDIO_CHANNELS environment variable
    public private(set) var audioChannels: Int = 1

    /// Audio bit rate for voice recordings (bits per second)
    /// Can be overridden with SONORA_AUDIO_BITRATE environment variable
    /// Voice-optimized default: 64000 bps for optimal clarity/size balance
    public private(set) var audioBitRate: Int = 64_000

    /// Voice-optimized audio quality (0.0 to 1.0)
    /// Can be overridden with SONORA_VOICE_QUALITY environment variable
    /// Calibrated specifically for voice content: 0.7 provides excellent speech clarity
    public private(set) var voiceOptimizedQuality: Float = 0.7

    /// Enable adaptive quality based on content type and system conditions
    /// Can be overridden with SONORA_ADAPTIVE_QUALITY environment variable
    public private(set) var enableAdaptiveAudioQuality: Bool = true

    // MARK: - Network Configuration

    /// Maximum number of retry attempts for failed network requests
    /// Can be overridden with SONORA_MAX_RETRIES environment variable
    public private(set) var maxNetworkRetries: Int = 3

    /// Base delay between retry attempts in seconds (exponential backoff applied)
    /// Can be overridden with SONORA_RETRY_DELAY environment variable
    public private(set) var retryBaseDelay: TimeInterval = 1.0

    /// Maximum concurrent network operations
    /// Can be overridden with SONORA_MAX_CONCURRENT_OPERATIONS environment variable
    public private(set) var maxConcurrentNetworkOperations: Int = 3

    /// URLSession configuration timeout for resource loading
    /// Can be overridden with SONORA_RESOURCE_TIMEOUT environment variable
    public private(set) var resourceTimeoutInterval: TimeInterval = 30.0

    // MARK: - Analysis Configuration

    /// Timeout for Distill analysis operations
    /// Can be overridden with SONORA_DISTILL_TIMEOUT environment variable
    /// GPT-5 family responses can exceed 60s for long outputs; default to 180s.
    public private(set) var distillAnalysisTimeout: TimeInterval = 180.0

    /// Timeout for content analysis operations
    /// Can be overridden with SONORA_CONTENT_TIMEOUT environment variable
    public private(set) var contentAnalysisTimeout: TimeInterval = 20.0

    /// Timeout for themes analysis operations
    /// Can be overridden with SONORA_THEMES_TIMEOUT environment variable
    public private(set) var themesAnalysisTimeout: TimeInterval = 18.0

    /// Timeout for todos analysis operations
    /// Can be overridden with SONORA_TODOS_TIMEOUT environment variable
    public private(set) var todosAnalysisTimeout: TimeInterval = 16.0

    /// Timeout for pro-tier analysis operations (Cognitive Clarity, Philosophical Echoes, Values Recognition)
    /// Can be overridden with SONORA_PRO_MODE_TIMEOUT environment variable
    /// Pro modes require extended timeout for deep reasoning and analysis
    public private(set) var proModeAnalysisTimeout: TimeInterval = 420.0

    /// Minimum transcript length required for analysis (characters)
    /// Can be overridden with SONORA_MIN_TRANSCRIPT_LENGTH environment variable
    public private(set) var minimumTranscriptLength: Int = 10

    /// Maximum transcript length for analysis (characters)
    /// Can be overridden with SONORA_MAX_TRANSCRIPT_LENGTH environment variable
    public private(set) var maximumTranscriptLength: Int = 50_000

    // MARK: - Live Activity Configuration

    /// Update interval for Live Activities during recording (seconds)
    /// Can be overridden with SONORA_LIVE_ACTIVITY_UPDATE_INTERVAL environment variable
    public private(set) var liveActivityUpdateInterval: TimeInterval = 2.0

    /// Maximum duration to keep Live Activity active after recording stops (seconds)
    /// Can be overridden with SONORA_LIVE_ACTIVITY_GRACE_PERIOD environment variable
    public private(set) var liveActivityGracePeriod: TimeInterval = 30.0

    /// Whether to show detailed progress in Live Activities
    /// Can be overridden with SONORA_LIVE_ACTIVITY_DETAILED_PROGRESS environment variable
    public private(set) var liveActivityShowDetailedProgress: Bool = true

    /// Background refresh rate for Live Activities (seconds)
    /// Can be overridden with SONORA_BACKGROUND_REFRESH_RATE environment variable
    public private(set) var backgroundRefreshRate: TimeInterval = 5.0

    // MARK: - Cache Configuration

    /// Maximum number of analysis results to keep in memory cache
    /// Can be overridden with SONORA_MEMORY_CACHE_SIZE environment variable
    public private(set) var memoryCacheMaxSize: Int = 50

    /// Time to live for cached analysis results in seconds (24 hours default)
    /// Can be overridden with SONORA_CACHE_TTL environment variable
    public private(set) var analysisCacheTTL: TimeInterval = 86_400.0

    /// Whether to persist analysis cache to disk
    /// Can be overridden with SONORA_DISK_CACHE_ENABLED environment variable
    public private(set) var diskCacheEnabled: Bool = true

    // MARK: - Prompts Configuration
    /// Cooldown for recently shown prompts (minutes)
    /// Can be overridden with SONORA_PROMPT_COOLDOWN_MINUTES environment variable
    public private(set) var promptCooldownMinutes: Int = 3

    /// Minimum candidate target for exploration mode variety
    /// Can be overridden with SONORA_PROMPT_MIN_VARIETY environment variable
    public private(set) var promptMinVarietyTarget: Int = 10

    // MARK: - AI Routing (Phase 3)
    /// Enable progressive analysis routing (tiny -> small -> base) with early termination.
    /// Controlled via UserDefaults key "enableProgressiveAnalysisRouting" or env SONORA_ENABLE_PROGRESSIVE_ANALYSIS
    public var enableProgressiveAnalysisRouting: Bool {
        get { UserDefaults.standard.object(forKey: "enableProgressiveAnalysisRouting") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "enableProgressiveAnalysisRouting") }
    }

    // Auto Title always enabled

    // MARK: - Effective Recording Cap (by service)
    /// Returns the effective recording cap in seconds based on the user's selected transcription service.
    /// Daily quota is enforced elsewhere; there is no global per-session cap.
    public var effectiveRecordingCapSeconds: TimeInterval? {
        nil // no fixed per-session limit; use remaining daily quota if needed
    }

    // MARK: - Voice Optimization Methods

    /// Returns the optimal audio quality based on content type and system conditions
    /// - Parameter contentType: The type of content being recorded (voice, music, etc.)
    /// - Parameter batteryLevel: Current battery level (0.0 to 1.0), -1 if unknown
    /// - Returns: Optimized quality value for the given conditions
    public func getOptimalAudioQuality(for contentType: AudioContentType = .voice, batteryLevel: Float = -1) -> Float {
        guard enableAdaptiveAudioQuality else {
            return contentType == .voice ? voiceOptimizedQuality : recordingQuality
        }

        // Adaptive quality based on system conditions
        let baseQuality = contentType == .voice ? voiceOptimizedQuality : recordingQuality

        // Reduce quality on low battery
        if batteryLevel >= 0 && batteryLevel < 0.2 {
            return max(0.5, baseQuality * 0.8)
        }

        // Check thermal state
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .serious || thermalState == .critical {
            return max(0.5, baseQuality * 0.85)
        }

        return baseQuality
    }

    /// Returns the optimal bit rate based on content type and system conditions
    /// - Parameter contentType: The type of content being recorded
    /// - Parameter batteryLevel: Current battery level (0.0 to 1.0), -1 if unknown
    /// - Returns: Optimized bit rate for the given conditions
    public func getOptimalBitRate(for contentType: AudioContentType = .voice, batteryLevel: Float = -1) -> Int {
        let baseBitRate = contentType == .voice ? audioBitRate : 128_000

        guard enableAdaptiveAudioQuality else { return baseBitRate }

        // Reduce bit rate on low battery or thermal pressure
        if (batteryLevel >= 0 && batteryLevel < 0.2) || ProcessInfo.processInfo.thermalState.rawValue >= 2 {
            return max(32_000, Int(Double(baseBitRate) * 0.75))
        }

        return baseBitRate
    }

    /// Returns voice-optimized sample rate (22050 Hz)
    /// This sample rate is perfect for voice content as it captures frequencies up to 11 kHz,
    /// which covers the full range of human speech (300-3400 Hz fundamental, harmonics up to 8 kHz)
    public var voiceOptimizedSampleRate: Double {
        22_050.0
    }

    /// Returns high-quality sample rate for music or mixed content (44100 Hz)
    public var highQualitySampleRate: Double {
        44_100.0
    }

    // MARK: - Search / Spotlight
    /// Whether Core Spotlight indexing is enabled (user can opt out in Settings in future)
    public var searchIndexingEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "searchIndexingEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "searchIndexingEnabled") }
    }

    // MARK: - Configuration Loading

    private func loadConfiguration() {
        // Load build-specific defaults first
        loadBuildSpecificDefaults()

        // Then override with environment variables if present
        loadEnvironmentOverrides()

        // Load persisted user preference for transcription language
        if let saved = UserDefaults.standard.string(forKey: "preferredTranscriptionLanguage"), !saved.isEmpty {
            preferredTranscriptionLanguage = saved
            print("🔧 AppConfiguration: Loaded preferred transcription language: \(saved)")
        } else if preferredTranscriptionLanguage == nil {
            preferredTranscriptionLanguage = "en"
            UserDefaults.standard.set("en", forKey: "preferredTranscriptionLanguage")
            print("🔧 AppConfiguration: Defaulting preferred transcription language to English")
        }
    }

    private func loadBuildSpecificDefaults() {
        // Compose per-section defaults
        let api = APIConfig.defaults(build: buildConfig)
        let rec = RecordingConfig.defaults(build: buildConfig)
        let net = NetworkConfig.defaults(build: buildConfig)
        let ana = AnalysisConfig.defaults(build: buildConfig)
        let liv = LiveActivityConfig.defaults(build: buildConfig)
        let cache = CacheConfig.defaults(build: buildConfig)
        let prompts = PromptsConfig.defaults()

        // Apply to current aggregate
        apiBaseURL = api.baseURL
        analysisTimeoutInterval = api.analysisTimeout
        transcriptionTimeoutInterval = api.transcriptionTimeout
        preferredTranscriptionLanguage = api.preferredTranscriptionLanguage
        healthCheckTimeoutInterval = api.healthTimeout

        maxRecordingDuration = rec.maxRecordingDuration
        maxRecordingFileSize = rec.maxRecordingFileSize
        recordingQuality = rec.recordingQuality
        audioSampleRate = rec.audioSampleRate
        audioChannels = rec.audioChannels
        audioBitRate = rec.audioBitRate
        voiceOptimizedQuality = rec.voiceOptimizedQuality
        enableAdaptiveAudioQuality = rec.enableAdaptiveAudioQuality

        maxNetworkRetries = net.maxNetworkRetries
        retryBaseDelay = net.retryBaseDelay
        maxConcurrentNetworkOperations = net.maxConcurrentNetworkOperations
        resourceTimeoutInterval = net.resourceTimeoutInterval

        distillAnalysisTimeout = ana.distillAnalysisTimeout
        contentAnalysisTimeout = ana.contentAnalysisTimeout
        themesAnalysisTimeout = ana.themesAnalysisTimeout
        todosAnalysisTimeout = ana.todosAnalysisTimeout
        proModeAnalysisTimeout = ana.proModeAnalysisTimeout
        minimumTranscriptLength = ana.minimumTranscriptLength
        maximumTranscriptLength = ana.maximumTranscriptLength

        liveActivityUpdateInterval = liv.liveActivityUpdateInterval
        liveActivityGracePeriod = liv.liveActivityGracePeriod
        liveActivityShowDetailedProgress = liv.liveActivityShowDetailedProgress
        backgroundRefreshRate = liv.backgroundRefreshRate

        memoryCacheMaxSize = cache.memoryCacheMaxSize
        analysisCacheTTL = cache.analysisCacheTTL
        diskCacheEnabled = cache.diskCacheEnabled

        promptCooldownMinutes = prompts.promptCooldownMinutes
        promptMinVarietyTarget = prompts.promptMinVarietyTarget

        // Log the loaded configuration
        logLoadedConfiguration()

        // Phase 3: Enable progressive analysis routing by default (can be toggled in Settings or env)
        if UserDefaults.standard.object(forKey: "enableProgressiveAnalysisRouting") == nil {
            UserDefaults.standard.set(true, forKey: "enableProgressiveAnalysisRouting")
        }
    }

    private func loadEnvironmentOverrides() {
        let env = ProcessInfo.processInfo.environment

        // Compose per-section overrides starting from current state
        let api = APIConfig(
            baseURL: apiBaseURL,
            analysisTimeout: analysisTimeoutInterval,
            transcriptionTimeout: transcriptionTimeoutInterval,
            preferredTranscriptionLanguage: preferredTranscriptionLanguage,
            healthTimeout: healthCheckTimeoutInterval
        ).withOverrides(env: env)
        let rec = RecordingConfig(
            maxRecordingDuration: maxRecordingDuration,
            maxRecordingFileSize: maxRecordingFileSize,
            recordingQuality: recordingQuality,
            audioSampleRate: audioSampleRate,
            audioChannels: audioChannels,
            audioBitRate: audioBitRate,
            voiceOptimizedQuality: voiceOptimizedQuality,
            enableAdaptiveAudioQuality: enableAdaptiveAudioQuality
        ).withOverrides(env: env)
        let net = NetworkConfig(
            maxNetworkRetries: maxNetworkRetries,
            retryBaseDelay: retryBaseDelay,
            maxConcurrentNetworkOperations: maxConcurrentNetworkOperations,
            resourceTimeoutInterval: resourceTimeoutInterval
        ).withOverrides(env: env)
        let ana = AnalysisConfig(
            distillAnalysisTimeout: distillAnalysisTimeout,
            contentAnalysisTimeout: contentAnalysisTimeout,
            themesAnalysisTimeout: themesAnalysisTimeout,
            todosAnalysisTimeout: todosAnalysisTimeout,
            proModeAnalysisTimeout: proModeAnalysisTimeout,
            minimumTranscriptLength: minimumTranscriptLength,
            maximumTranscriptLength: maximumTranscriptLength
        ).withOverrides(env: env)
        let liv = LiveActivityConfig(
            liveActivityUpdateInterval: liveActivityUpdateInterval,
            liveActivityGracePeriod: liveActivityGracePeriod,
            liveActivityShowDetailedProgress: liveActivityShowDetailedProgress,
            backgroundRefreshRate: backgroundRefreshRate
        ).withOverrides(env: env)
        let cache = CacheConfig(
            memoryCacheMaxSize: memoryCacheMaxSize,
            analysisCacheTTL: analysisCacheTTL,
            diskCacheEnabled: diskCacheEnabled
        ).withOverrides(env: env)
        let prompts = PromptsConfig(
            promptCooldownMinutes: promptCooldownMinutes,
            promptMinVarietyTarget: promptMinVarietyTarget
        ).withOverrides(env: env)

        // Apply back to aggregate
        apiBaseURL = api.baseURL
        analysisTimeoutInterval = api.analysisTimeout
        transcriptionTimeoutInterval = api.transcriptionTimeout
        preferredTranscriptionLanguage = api.preferredTranscriptionLanguage
        healthCheckTimeoutInterval = api.healthTimeout

        maxRecordingDuration = rec.maxRecordingDuration
        maxRecordingFileSize = rec.maxRecordingFileSize
        recordingQuality = rec.recordingQuality
        audioSampleRate = rec.audioSampleRate
        audioChannels = rec.audioChannels
        audioBitRate = rec.audioBitRate
        voiceOptimizedQuality = rec.voiceOptimizedQuality
        enableAdaptiveAudioQuality = rec.enableAdaptiveAudioQuality

        maxNetworkRetries = net.maxNetworkRetries
        retryBaseDelay = net.retryBaseDelay
        maxConcurrentNetworkOperations = net.maxConcurrentNetworkOperations
        resourceTimeoutInterval = net.resourceTimeoutInterval

        distillAnalysisTimeout = ana.distillAnalysisTimeout
        contentAnalysisTimeout = ana.contentAnalysisTimeout
        themesAnalysisTimeout = ana.themesAnalysisTimeout
        todosAnalysisTimeout = ana.todosAnalysisTimeout
        proModeAnalysisTimeout = ana.proModeAnalysisTimeout
        minimumTranscriptLength = ana.minimumTranscriptLength
        maximumTranscriptLength = ana.maximumTranscriptLength

        liveActivityUpdateInterval = liv.liveActivityUpdateInterval
        liveActivityGracePeriod = liv.liveActivityGracePeriod
        liveActivityShowDetailedProgress = liv.liveActivityShowDetailedProgress
        backgroundRefreshRate = liv.backgroundRefreshRate

        memoryCacheMaxSize = cache.memoryCacheMaxSize
        analysisCacheTTL = cache.analysisCacheTTL
        diskCacheEnabled = cache.diskCacheEnabled

        promptCooldownMinutes = prompts.promptCooldownMinutes
        promptMinVarietyTarget = prompts.promptMinVarietyTarget
    }

    private func logLoadedConfiguration() {
        print("🔧 AppConfiguration loaded:")
        print("   Build: \(buildConfig.buildType.displayName) (\(buildConfig.distributionType.displayName))")
        print("   API Base URL: \(apiBaseURL.absoluteString)")
        print("   Analysis Timeout: \(analysisTimeoutInterval)s")
        print("   Transcription Timeout: \(transcriptionTimeoutInterval)s")
        print("   Max Recording Duration: \(formattedMaxDuration)")
        print("   Max File Size: \(formattedMaxFileSize)")
        print("   Recording Quality: \(recordingQuality)")
        print("   Max Network Retries: \(maxNetworkRetries)")
        print("   Live Activity Updates: \(liveActivityUpdateInterval)s")
        print("   Memory Cache Size: \(memoryCacheMaxSize)")
        print("   Cache TTL: \(Int(analysisCacheTTL / 3_600))h")
        print("   Disk Cache: \(diskCacheEnabled)")
    }

    // MARK: - Public Methods

    /// Get timeout for specific analysis mode
    public func timeoutInterval(for mode: AnalysisMode) -> TimeInterval {
        switch mode {
        case .distill:
            return distillAnalysisTimeout
        // Distill component modes use half the distill timeout (no artificial clamping)
        case .distillSummary, .distillActions, .distillThemes, .distillPersonalInsight, .distillClosingNote, .distillReflection:
            return distillAnalysisTimeout / 2 // Half the distill timeout for focused component analysis
        case .liteDistill:
            return min(distillAnalysisTimeout / 2, 10.0) // Lite Distill is even faster
        case .events:
            return contentAnalysisTimeout // Use same timeout as content analysis
        case .reminders:
            return contentAnalysisTimeout // Use same timeout as content analysis
        }
    }

    /// Validate if transcript length is within acceptable bounds
    public func isValidTranscriptLength(_ length: Int) -> Bool {
        length >= minimumTranscriptLength && length <= maximumTranscriptLength
    }

    /// Get formatted file size limit for display
    public var formattedMaxFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: maxRecordingFileSize)
    }

    /// Get formatted recording duration limit for display
    public var formattedMaxDuration: String {
        let hours = Int(maxRecordingDuration) / 3_600
        let minutes = Int(maxRecordingDuration) % 3_600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Get build-specific configuration suffix
    public var buildConfigurationSuffix: String {
        buildConfig.configurationSuffix
    }

    /// Get current build information for debugging
    public var buildInformation: String {
        """
        Build Information:
        - Type: \(buildConfig.buildType.displayName)
        - Distribution: \(buildConfig.distributionType.displayName)
        - Version: \(buildConfig.fullVersionString)
        - Bundle ID: \(buildConfig.bundleIdentifier)
        - API URL: \(apiBaseURL.absoluteString)
        - Environment: \(buildConfig.isDebug ? "Debug" : "Release")
        """
    }

    /// Force reload configuration (useful for testing and debugging)
    public func reloadConfiguration() {
        loadConfiguration()
    }

    /// Update user's preferred transcription language and persist
    /// Pass nil or "auto" to reset to auto-detect
    public func setPreferredTranscriptionLanguage(_ code: String?) {
        let normalized: String?
        if let c = code?.lowercased(), c != "auto", !c.isEmpty {
            guard WhisperLanguages.supportedCodes.contains(c) else {
                print("⚠️ AppConfiguration: Ignoring unsupported transcription language code: \(c)")
                return
            }
            normalized = c
        } else {
            normalized = nil
        }
        preferredTranscriptionLanguage = normalized
        if let normalized { UserDefaults.standard.set(normalized, forKey: "preferredTranscriptionLanguage") } else { UserDefaults.standard.removeObject(forKey: "preferredTranscriptionLanguage") }
        print("🔧 AppConfiguration: Preferred transcription language set to: \(preferredTranscriptionLanguage ?? "auto")")
    }

    /// Validate configuration consistency
    public func validateConfiguration() -> [String] {
        var warnings: [String] = []

        // Add build configuration warnings
        warnings.append(contentsOf: buildConfig.validateConfiguration())

        // Check for configuration inconsistencies
        if buildConfig.isDebug && apiBaseURL.absoluteString == "https://sonora.fly.dev" {
            warnings.append("Debug build using production API URL")
        }

        if buildConfig.isRelease && analysisTimeoutInterval > 30.0 {
            warnings.append("Release build with unusually long analysis timeout")
        }

        if maxRecordingDuration < 300.0 { // Less than 5 minutes
            warnings.append("Very short maximum recording duration configured")
        }

        if maxRecordingFileSize < 10 * 1_024 * 1_024 { // Less than 10MB
            warnings.append("Very small maximum file size configured")
        }

        return warnings
    }
}

// MARK: - Audio Content Type

/// Defines the type of audio content being recorded for optimization
public enum AudioContentType: String, CaseIterable, Sendable {
    case voice
    case music
    case mixed

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .voice:
            return "Voice"
        case .music:
            return "Music"
        case .mixed:
            return "Mixed Content"
        }
    }

    /// Recommended sample rate for this content type
    public var recommendedSampleRate: Double {
        switch self {
        case .voice:
            return 22_050.0
        case .music, .mixed:
            return 44_100.0
        }
    }

    /// Recommended bit rate for this content type
    public var recommendedBitRate: Int {
        switch self {
        case .voice:
            return 64_000
        case .music:
            return 128_000
        case .mixed:
            return 96_000
        }
    }
}

// AppConfiguration is a shared configuration holder accessed primarily on the main actor.
// Mark it as unchecked Sendable to silence static 'shared' diagnostics under strict concurrency.
extension AppConfiguration: @unchecked Sendable {}
