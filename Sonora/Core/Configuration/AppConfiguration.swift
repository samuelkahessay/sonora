import Foundation

/// Centralized application configuration management
/// Provides type-safe access to all app configuration values with environment variable support
public final class AppConfiguration {
    
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
    
    /// API request timeout for health check operations (in seconds)
    /// Can be overridden with SONORA_HEALTH_TIMEOUT environment variable
    public private(set) var healthCheckTimeoutInterval: TimeInterval = 5.0
    
    // MARK: - Recording Configuration
    
    /// Maximum recording duration in seconds
    /// Can be overridden with SONORA_MAX_RECORDING_DURATION environment variable
    public private(set) var maxRecordingDuration: TimeInterval = 3600.0 // 1 hour
    
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
    public private(set) var audioSampleRate: Double = 44100.0
    
    /// Number of audio channels (1 = mono, 2 = stereo)
    /// Can be overridden with SONORA_AUDIO_CHANNELS environment variable
    public private(set) var audioChannels: Int = 1
    
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
    
    /// Timeout for TLDR analysis operations
    /// Can be overridden with SONORA_TLDR_TIMEOUT environment variable
    public private(set) var tldrAnalysisTimeout: TimeInterval = 15.0
    
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
    
    // MARK: - Configuration Loading
    
    private func loadConfiguration() {
        // Load build-specific defaults first
        loadBuildSpecificDefaults()
        
        // Then override with environment variables if present
        loadEnvironmentOverrides()
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
        
        // Recording Configuration - Build-specific limits
        if buildConfig.isDebug {
            // Debug builds get more generous limits for testing
            maxRecordingDuration = 7200.0 // 2 hours
            maxRecordingFileSize = 100 * 1024 * 1024 // 100MB
            recordingQuality = 1.0 // Highest quality for development
        } else {
            // Release builds use production limits
            maxRecordingDuration = 3600.0 // 1 hour
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
            tldrAnalysisTimeout = 25.0
            contentAnalysisTimeout = 35.0
            themesAnalysisTimeout = 30.0
            todosAnalysisTimeout = 28.0
        } else {
            // Release builds use optimized timeouts
            tldrAnalysisTimeout = 15.0
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
        
        // Log the loaded configuration
        logLoadedConfiguration()
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
        if let timeoutString = ProcessInfo.processInfo.environment["SONORA_TLDR_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            tldrAnalysisTimeout = timeout
            print("🔧 AppConfiguration: TLDR timeout overridden to \(timeout)s")
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
        case .tldr:
            return tldrAnalysisTimeout
        case .analysis:
            return contentAnalysisTimeout
        case .themes:
            return themesAnalysisTimeout
        case .todos:
            return todosAnalysisTimeout
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

// MARK: - AnalysisMode Extension

extension AnalysisMode {
    /// Get the configured timeout for this analysis mode
    var configuredTimeout: TimeInterval {
        return AppConfiguration.shared.timeoutInterval(for: self)
    }
}
