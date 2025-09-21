import Foundation
import Combine

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
        return BuildConfiguration.shared
    }
    
    // MARK: - API Configuration
    
    /// Base URL for the Sonora API
    /// Can be overridden with SONORA_API_URL environment variable
    public private(set) var apiBaseURL: URL = URL(string: "https://sonora.fly.dev")!
    
    /// API request timeout for analysis operations (in seconds)
    /// Can be overridden with SONORA_ANALYSIS_TIMEOUT environment variable
    public private(set) var analysisTimeoutInterval: TimeInterval = 12.0
    
    /// API request timeout for transcription operations (in seconds)
    /// Can be overridden with SONORA_TRANSCRIPTION_TIMEOUT environment variable
    public private(set) var transcriptionTimeoutInterval: TimeInterval = 120.0

    /// Preferred transcription language hint (ISO 639-1) or nil for Auto
    /// Can be overridden with SONORA_TRANSCRIPTION_LANGUAGE environment variable
    public private(set) var preferredTranscriptionLanguage: String? = nil
    
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
    public private(set) var maxRecordingFileSize: Int64 = 50 * 1024 * 1024
    
    /// Recording quality setting (0.0 to 1.0, where 1.0 is highest quality)
    /// Can be overridden with SONORA_RECORDING_QUALITY environment variable
    public private(set) var recordingQuality: Float = 0.8
    
    /// Audio format for recordings
    public let recordingFormat: String = "m4a"
    
    /// Sample rate for audio recordings
    /// Can be overridden with SONORA_SAMPLE_RATE environment variable
    /// Voice-optimized default: 22050 Hz (perfect for voice content)
    public private(set) var audioSampleRate: Double = 22050.0
    
    /// Number of audio channels (1 = mono, 2 = stereo)
    /// Can be overridden with SONORA_AUDIO_CHANNELS environment variable
    public private(set) var audioChannels: Int = 1
    
    /// Audio bit rate for voice recordings (bits per second)
    /// Can be overridden with SONORA_AUDIO_BITRATE environment variable
    /// Voice-optimized default: 64000 bps for optimal clarity/size balance
    public private(set) var audioBitRate: Int = 64000
    
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
    public private(set) var distillAnalysisTimeout: TimeInterval = 35.0
    
    /// Timeout for content analysis operations
    /// Can be overridden with SONORA_CONTENT_TIMEOUT environment variable
    public private(set) var contentAnalysisTimeout: TimeInterval = 20.0
    
    /// Timeout for themes analysis operations
    /// Can be overridden with SONORA_THEMES_TIMEOUT environment variable
    public private(set) var themesAnalysisTimeout: TimeInterval = 18.0
    
    /// Timeout for todos analysis operations
    /// Can be overridden with SONORA_TODOS_TIMEOUT environment variable
    public private(set) var todosAnalysisTimeout: TimeInterval = 16.0
    
    /// Minimum transcript length required for analysis (characters)
    /// Can be overridden with SONORA_MIN_TRANSCRIPT_LENGTH environment variable
    public private(set) var minimumTranscriptLength: Int = 10
    
    /// Maximum transcript length for analysis (characters)
    /// Can be overridden with SONORA_MAX_TRANSCRIPT_LENGTH environment variable
    public private(set) var maximumTranscriptLength: Int = 50000
    
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
    public private(set) var analysisCacheTTL: TimeInterval = 86400.0
    
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

    // MARK: - Effective Recording Cap (by service)
    /// Returns the effective recording cap in seconds based on the user's selected transcription service.
    /// Daily quota is enforced elsewhere; there is no global per-session cap.
    public var effectiveRecordingCapSeconds: TimeInterval? {
        return nil // no fixed per-session limit; use remaining daily quota if needed
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
        let baseBitRate = contentType == .voice ? audioBitRate : 128000
        
        guard enableAdaptiveAudioQuality else { return baseBitRate }
        
        // Reduce bit rate on low battery or thermal pressure
        if (batteryLevel >= 0 && batteryLevel < 0.2) || ProcessInfo.processInfo.thermalState.rawValue >= 2 {
            return max(32000, Int(Double(baseBitRate) * 0.75))
        }
        
        return baseBitRate
    }
    
    /// Returns voice-optimized sample rate (22050 Hz)
    /// This sample rate is perfect for voice content as it captures frequencies up to 11 kHz,
    /// which covers the full range of human speech (300-3400 Hz fundamental, harmonics up to 8 kHz)
    public var voiceOptimizedSampleRate: Double {
        return 22050.0
    }
    
    /// Returns high-quality sample rate for music or mixed content (44100 Hz)
    public var highQualitySampleRate: Double {
        return 44100.0
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
        // API Configuration - Build-specific URLs
        switch (buildConfig.buildType, buildConfig.distributionType) {
        case (.debug, .development):
            apiBaseURL = URL(string: "https://sonora.fly.dev")!
            analysisTimeoutInterval = 30.0 // Longer timeouts for development
            transcriptionTimeoutInterval = 180.0
            healthCheckTimeoutInterval = 10.0
            
        case (.testing, _):
            apiBaseURL = URL(string: "https://sonora.fly.dev")!
            analysisTimeoutInterval = 15.0
            transcriptionTimeoutInterval = 120.0
            healthCheckTimeoutInterval = 8.0
            
        case (.release, .testFlight):
            apiBaseURL = URL(string: "https://sonora.fly.dev")!
            analysisTimeoutInterval = 15.0
            transcriptionTimeoutInterval = 120.0
            healthCheckTimeoutInterval = 6.0
            
        case (.release, .appStore):
            apiBaseURL = URL(string: "https://sonora.fly.dev")!
            analysisTimeoutInterval = 12.0
            transcriptionTimeoutInterval = 120.0
            healthCheckTimeoutInterval = 5.0
            
        default:
            // Default to production for unknown configurations
            apiBaseURL = URL(string: "https://sonora.fly.dev")!
            analysisTimeoutInterval = 12.0
            transcriptionTimeoutInterval = 120.0
            healthCheckTimeoutInterval = 5.0
        }
        
        // Recording Configuration - Legacy parameter (no per-session cap enforced)
        maxRecordingDuration = 180.0
        if buildConfig.isDebug {
            maxRecordingFileSize = 100 * 1024 * 1024 // 100MB
            recordingQuality = 1.0 // Highest quality for development
        } else {
            maxRecordingFileSize = 50 * 1024 * 1024 // 50MB
            recordingQuality = 0.8 // Balanced quality
        }
        
        // Network Configuration - Build-specific retry behavior
        if buildConfig.isDebug {
            maxNetworkRetries = 5 // More retries for debugging
            retryBaseDelay = 2.0 // Longer delays for debugging
            maxConcurrentNetworkOperations = 2 // Fewer concurrent operations for debugging
            resourceTimeoutInterval = 60.0 // Longer resource timeouts
        } else {
            maxNetworkRetries = 3 // Standard retries for production
            retryBaseDelay = 1.0 // Quick retries for production
            maxConcurrentNetworkOperations = 3 // More concurrent operations for performance
            resourceTimeoutInterval = 30.0 // Standard resource timeouts
        }
        
        // Analysis Configuration - Build-specific timeouts
        if buildConfig.isDebug {
            // Debug builds get longer timeouts for easier debugging
            distillAnalysisTimeout = 35.0
            contentAnalysisTimeout = 35.0
            themesAnalysisTimeout = 30.0
            todosAnalysisTimeout = 28.0
        } else {
            // Release builds use optimized timeouts
            distillAnalysisTimeout = 35.0
            contentAnalysisTimeout = 20.0
            themesAnalysisTimeout = 18.0
            todosAnalysisTimeout = 16.0
        }
        
        // Live Activity Configuration - Build-specific behavior
        if buildConfig.isDebug {
            liveActivityUpdateInterval = 1.0 // More frequent updates for debugging
            liveActivityGracePeriod = 60.0 // Longer grace period for debugging
            backgroundRefreshRate = 2.0 // More frequent background refresh
        } else {
            liveActivityUpdateInterval = 2.0 // Standard update interval
            liveActivityGracePeriod = 30.0 // Standard grace period
            backgroundRefreshRate = 5.0 // Standard background refresh
        }
        
        // Cache Configuration - Build-specific caching
        if buildConfig.isDebug {
            memoryCacheMaxSize = 100 // Larger cache for development
            analysisCacheTTL = 43200.0 // 12 hours for debugging
        } else {
            memoryCacheMaxSize = 50 // Standard cache size
            analysisCacheTTL = 86400.0 // 24 hours for production
        }
        
        diskCacheEnabled = true // Always enable disk cache

        // Prompts Configuration - Defaults
        promptCooldownMinutes = 3
        promptMinVarietyTarget = 10

        // Log the loaded configuration
        logLoadedConfiguration()

        // Phase 3: Enable progressive analysis routing by default (can be toggled in Settings or env)
        if UserDefaults.standard.object(forKey: "enableProgressiveAnalysisRouting") == nil {
            UserDefaults.standard.set(true, forKey: "enableProgressiveAnalysisRouting")
        }
    }
    
    private func loadEnvironmentOverrides() {
        // API Configuration
        if let apiURLString = ProcessInfo.processInfo.environment["SONORA_API_URL"],
           let url = URL(string: apiURLString) {
            apiBaseURL = url
            print("🔧 AppConfiguration: API URL overridden to \(apiBaseURL.absoluteString)")
        }
        
        if let timeoutString = ProcessInfo.processInfo.environment["SONORA_ANALYSIS_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            analysisTimeoutInterval = timeout
            print("🔧 AppConfiguration: Analysis timeout overridden to \(timeout)s")
        }
        
        if let timeoutString = ProcessInfo.processInfo.environment["SONORA_TRANSCRIPTION_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            transcriptionTimeoutInterval = timeout
            print("🔧 AppConfiguration: Transcription timeout overridden to \(timeout)s")
        }
        
        if let lang = ProcessInfo.processInfo.environment["SONORA_TRANSCRIPTION_LANGUAGE"], !lang.isEmpty {
            preferredTranscriptionLanguage = lang.lowercased()
            print("🔧 AppConfiguration: Preferred transcription language overridden to \(lang)")
        }
        
        if let timeoutString = ProcessInfo.processInfo.environment["SONORA_HEALTH_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            healthCheckTimeoutInterval = timeout
            print("🔧 AppConfiguration: Health check timeout overridden to \(timeout)s")
        }
        
        // Recording Configuration
        if let durationString = ProcessInfo.processInfo.environment["SONORA_MAX_RECORDING_DURATION"],
           let duration = TimeInterval(durationString) {
            maxRecordingDuration = duration
            print("🔧 AppConfiguration: Max recording duration overridden to \(duration)s")
        }
        
        if let sizeString = ProcessInfo.processInfo.environment["SONORA_MAX_FILE_SIZE"],
           let size = Int64(sizeString) {
            maxRecordingFileSize = size
            print("🔧 AppConfiguration: Max file size overridden to \(size) bytes")
        }
        
        if let qualityString = ProcessInfo.processInfo.environment["SONORA_RECORDING_QUALITY"],
           let quality = Float(qualityString) {
            recordingQuality = max(0.0, min(1.0, quality))
            print("🔧 AppConfiguration: Recording quality overridden to \(recordingQuality)")
        }
        
        if let sampleRateString = ProcessInfo.processInfo.environment["SONORA_SAMPLE_RATE"],
           let sampleRate = Double(sampleRateString) {
            audioSampleRate = sampleRate
            print("🔧 AppConfiguration: Audio sample rate overridden to \(sampleRate)")
        }
        
        if let channelsString = ProcessInfo.processInfo.environment["SONORA_AUDIO_CHANNELS"],
           let channels = Int(channelsString) {
            audioChannels = max(1, min(2, channels))
            print("🔧 AppConfiguration: Audio channels overridden to \(audioChannels)")
        }
        
        if let bitRateString = ProcessInfo.processInfo.environment["SONORA_AUDIO_BITRATE"],
           let bitRate = Int(bitRateString) {
            audioBitRate = max(32000, min(320000, bitRate))
            print("🔧 AppConfiguration: Audio bit rate overridden to \(audioBitRate)")
        }
        
        if let voiceQualityString = ProcessInfo.processInfo.environment["SONORA_VOICE_QUALITY"],
           let voiceQuality = Float(voiceQualityString) {
            voiceOptimizedQuality = max(0.0, min(1.0, voiceQuality))
            print("🔧 AppConfiguration: Voice quality overridden to \(voiceOptimizedQuality)")
        }
        
        if let adaptiveString = ProcessInfo.processInfo.environment["SONORA_ADAPTIVE_QUALITY"],
           let adaptive = Bool(adaptiveString) {
            enableAdaptiveAudioQuality = adaptive
            print("🔧 AppConfiguration: Adaptive quality overridden to \(enableAdaptiveAudioQuality)")
        }
        // Network Configuration
        if let retriesString = ProcessInfo.processInfo.environment["SONORA_MAX_RETRIES"],
           let retries = Int(retriesString) {
            maxNetworkRetries = max(0, retries)
            print("🔧 AppConfiguration: Max retries overridden to \(maxNetworkRetries)")
        }
        
        if let delayString = ProcessInfo.processInfo.environment["SONORA_RETRY_DELAY"],
           let delay = TimeInterval(delayString) {
            retryBaseDelay = max(0.1, delay)
            print("🔧 AppConfiguration: Retry delay overridden to \(retryBaseDelay)s")
        }
        
        if let concurrentString = ProcessInfo.processInfo.environment["SONORA_MAX_CONCURRENT_OPERATIONS"],
           let concurrent = Int(concurrentString) {
            maxConcurrentNetworkOperations = max(1, concurrent)
            print("🔧 AppConfiguration: Max concurrent operations overridden to \(maxConcurrentNetworkOperations)")
        }
        
        if let timeoutString = ProcessInfo.processInfo.environment["SONORA_RESOURCE_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            resourceTimeoutInterval = timeout
            print("🔧 AppConfiguration: Resource timeout overridden to \(timeout)s")
        }
        
        // Analysis Configuration
        if let timeoutString = ProcessInfo.processInfo.environment["SONORA_DISTILL_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            distillAnalysisTimeout = timeout
            print("🔧 AppConfiguration: Distill timeout overridden to \(timeout)s")
        }
        
        if let timeoutString = ProcessInfo.processInfo.environment["SONORA_CONTENT_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            contentAnalysisTimeout = timeout
            print("🔧 AppConfiguration: Content timeout overridden to \(timeout)s")
        }
        
        if let timeoutString = ProcessInfo.processInfo.environment["SONORA_THEMES_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            themesAnalysisTimeout = timeout
            print("🔧 AppConfiguration: Themes timeout overridden to \(timeout)s")
        }
        
        if let timeoutString = ProcessInfo.processInfo.environment["SONORA_TODOS_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            todosAnalysisTimeout = timeout
            print("🔧 AppConfiguration: Todos timeout overridden to \(timeout)s")
        }
        
        if let lengthString = ProcessInfo.processInfo.environment["SONORA_MIN_TRANSCRIPT_LENGTH"],
           let length = Int(lengthString) {
            minimumTranscriptLength = max(1, length)
            print("🔧 AppConfiguration: Min transcript length overridden to \(minimumTranscriptLength)")
        }
        
        if let lengthString = ProcessInfo.processInfo.environment["SONORA_MAX_TRANSCRIPT_LENGTH"],
           let length = Int(lengthString) {
            maximumTranscriptLength = max(minimumTranscriptLength, length)
            print("🔧 AppConfiguration: Max transcript length overridden to \(maximumTranscriptLength)")
        }
        
        // Live Activity Configuration
        if let intervalString = ProcessInfo.processInfo.environment["SONORA_LIVE_ACTIVITY_UPDATE_INTERVAL"],
           let interval = TimeInterval(intervalString) {
            liveActivityUpdateInterval = max(0.5, interval)
            print("🔧 AppConfiguration: Live Activity update interval overridden to \(liveActivityUpdateInterval)s")
        }
        
        if let gracePeriodString = ProcessInfo.processInfo.environment["SONORA_LIVE_ACTIVITY_GRACE_PERIOD"],
           let gracePeriod = TimeInterval(gracePeriodString) {
            liveActivityGracePeriod = max(0.0, gracePeriod)
            print("🔧 AppConfiguration: Live Activity grace period overridden to \(liveActivityGracePeriod)s")
        }
        
        if let detailedProgressString = ProcessInfo.processInfo.environment["SONORA_LIVE_ACTIVITY_DETAILED_PROGRESS"],
           let detailedProgress = Bool(detailedProgressString) {
            liveActivityShowDetailedProgress = detailedProgress
            print("🔧 AppConfiguration: Live Activity detailed progress overridden to \(liveActivityShowDetailedProgress)")
        }
        
        if let refreshRateString = ProcessInfo.processInfo.environment["SONORA_BACKGROUND_REFRESH_RATE"],
           let refreshRate = TimeInterval(refreshRateString) {
            backgroundRefreshRate = max(1.0, refreshRate)
            print("🔧 AppConfiguration: Background refresh rate overridden to \(backgroundRefreshRate)s")
        }
        
        // Cache Configuration
        if let cacheSizeString = ProcessInfo.processInfo.environment["SONORA_MEMORY_CACHE_SIZE"],
           let cacheSize = Int(cacheSizeString) {
            memoryCacheMaxSize = max(1, cacheSize)
            print("🔧 AppConfiguration: Memory cache size overridden to \(memoryCacheMaxSize)")
        }
        
        if let ttlString = ProcessInfo.processInfo.environment["SONORA_CACHE_TTL"],
           let ttl = TimeInterval(ttlString) {
            analysisCacheTTL = max(60.0, ttl) // Minimum 1 minute
            print("🔧 AppConfiguration: Cache TTL overridden to \(analysisCacheTTL)s")
        }
        
        if let diskCacheString = ProcessInfo.processInfo.environment["SONORA_DISK_CACHE_ENABLED"],
           let diskCache = Bool(diskCacheString) {
            diskCacheEnabled = diskCache
            print("🔧 AppConfiguration: Disk cache overridden to \(diskCacheEnabled)")
        }

        // Prompts configuration
        if let cooldownStr = ProcessInfo.processInfo.environment["SONORA_PROMPT_COOLDOWN_MINUTES"],
           let mins = Int(cooldownStr) {
            promptCooldownMinutes = max(0, mins)
            print("🔧 AppConfiguration: Prompt cooldown overridden to \(promptCooldownMinutes) min")
        }
        if let varietyStr = ProcessInfo.processInfo.environment["SONORA_PROMPT_MIN_VARIETY"],
           let count = Int(varietyStr) {
            promptMinVarietyTarget = max(1, count)
            print("🔧 AppConfiguration: Prompt min variety target overridden to \(promptMinVarietyTarget)")
        }
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
        print("   Cache TTL: \(Int(analysisCacheTTL / 3600))h")
        print("   Disk Cache: \(diskCacheEnabled)")
    }
    
    // MARK: - Public Methods
    
    /// Get timeout for specific analysis mode
    public func timeoutInterval(for mode: AnalysisMode) -> TimeInterval {
        switch mode {
        case .distill:
            return distillAnalysisTimeout
        // Distill component modes use shorter timeouts since they're focused
        case .distillSummary, .distillActions, .distillThemes, .distillReflection:
            return min(distillAnalysisTimeout / 2, 15.0) // Half the distill timeout or 15s, whichever is lower
        case .analysis:
            return contentAnalysisTimeout
        case .themes:
            return themesAnalysisTimeout
        case .todos:
            return todosAnalysisTimeout
        case .events:
            return contentAnalysisTimeout // Use same timeout as content analysis
        case .reminders:
            return contentAnalysisTimeout // Use same timeout as content analysis
        }
    }
    
    /// Validate if transcript length is within acceptable bounds
    public func isValidTranscriptLength(_ length: Int) -> Bool {
        return length >= minimumTranscriptLength && length <= maximumTranscriptLength
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
        let hours = Int(maxRecordingDuration) / 3600
        let minutes = Int(maxRecordingDuration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Get build-specific configuration suffix
    public var buildConfigurationSuffix: String {
        return buildConfig.configurationSuffix
    }
    
    /// Get current build information for debugging
    public var buildInformation: String {
        return """
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
        if let normalized { UserDefaults.standard.set(normalized, forKey: "preferredTranscriptionLanguage") }
        else { UserDefaults.standard.removeObject(forKey: "preferredTranscriptionLanguage") }
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
        
        if maxRecordingFileSize < 10 * 1024 * 1024 { // Less than 10MB
            warnings.append("Very small maximum file size configured")
        }
        
        return warnings
    }
}

// MARK: - Audio Content Type

/// Defines the type of audio content being recorded for optimization
public enum AudioContentType: String, CaseIterable, Sendable {
    case voice = "voice"
    case music = "music"
    case mixed = "mixed"
    
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
            return 22050.0
        case .music, .mixed:
            return 44100.0
        }
    }
    
    /// Recommended bit rate for this content type
    public var recommendedBitRate: Int {
        switch self {
        case .voice:
            return 64000
        case .music:
            return 128000
        case .mixed:
            return 96000
        }
    }
}

// AppConfiguration is a shared configuration holder accessed primarily on the main actor.
// Mark it as unchecked Sendable to silence static 'shared' diagnostics under strict concurrency.
extension AppConfiguration: @unchecked Sendable {}
