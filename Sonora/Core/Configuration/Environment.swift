import Foundation
import UIKit

/// Environment configuration management for build-specific settings
/// Handles debug/release configurations, feature toggles, and development tools
public final class Environment: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = Environment()
    
    private init() {
        // Load environment configuration during initialization
        loadConfiguration()
    }
    
    // MARK: - Build Configuration
    
    /// Current build configuration
    public enum BuildConfiguration: String, CaseIterable {
        case debug = "Debug"
        case release = "Release"
        case testing = "Testing"
        
        var isDebug: Bool {
            return self == .debug || self == .testing
        }
        
        var isRelease: Bool {
            return self == .release
        }
        
        var displayName: String {
            return rawValue
        }
    }
    
    /// Current build configuration
    public private(set) var buildConfiguration: BuildConfiguration = .debug
    
    /// Whether the app is running in debug mode
    public var isDebug: Bool {
        return buildConfiguration.isDebug
    }
    
    /// Whether the app is running in release mode
    public var isRelease: Bool {
        return buildConfiguration.isRelease
    }
    
    /// Whether the app is running in testing mode
    public var isTesting: Bool {
        return buildConfiguration == .testing || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    // MARK: - Logging Configuration
    
    /// Default log level based on build configuration
    public var defaultLogLevel: LogLevel {
        switch buildConfiguration {
        case .debug:
            return .verbose
        case .release:
            return .warning
        case .testing:
            return .info
        }
    }
    
    /// Whether to log to console (always true in debug, configurable in release)
    /// Can be overridden with SONORA_LOG_TO_CONSOLE environment variable
    public private(set) var logToConsole: Bool = true
    
    /// Whether to log to file
    /// Can be overridden with SONORA_LOG_TO_FILE environment variable
    public private(set) var logToFile: Bool = false
    
    /// Whether to log to system (os_log)
    /// Can be overridden with SONORA_LOG_TO_SYSTEM environment variable
    public private(set) var logToSystem: Bool = true
    
    /// Maximum log file size in bytes (10MB default)
    /// Can be overridden with SONORA_MAX_LOG_FILE_SIZE environment variable
    public private(set) var maxLogFileSize: Int64 = 10 * 1024 * 1024
    
    /// Whether to include file and line information in logs
    /// Can be overridden with SONORA_LOG_INCLUDE_LOCATION environment variable
    public private(set) var logIncludeLocation: Bool = true
    
    /// Whether to include timestamps in console logs
    /// Can be overridden with SONORA_LOG_INCLUDE_TIMESTAMP environment variable
    public private(set) var logIncludeTimestamp: Bool = true
    
    /// Whether to use colored console output (debug only)
    /// Can be overridden with SONORA_LOG_USE_COLORS environment variable
    public private(set) var logUseColors: Bool = true
    
    // MARK: - Feature Toggles
    
    /// Whether Live Activities are enabled
    /// Can be overridden with SONORA_LIVE_ACTIVITIES_ENABLED environment variable
    public private(set) var liveActivitiesEnabled: Bool = true
    
    /// Whether Dynamic Island integration is enabled
    /// Can be overridden with SONORA_DYNAMIC_ISLAND_ENABLED environment variable
    public private(set) var dynamicIslandEnabled: Bool = true
    
    /// Whether background recording is enabled
    /// Can be overridden with SONORA_BACKGROUND_RECORDING_ENABLED environment variable
    public private(set) var backgroundRecordingEnabled: Bool = true
    
    /// Whether push notifications are enabled
    /// Can be overridden with SONORA_PUSH_NOTIFICATIONS_ENABLED environment variable
    public private(set) var pushNotificationsEnabled: Bool = false
    
    /// Whether analytics collection is enabled (always false in debug)
    /// Can be overridden with SONORA_ANALYTICS_ENABLED environment variable
    public private(set) var analyticsEnabled: Bool = false
    
    /// Whether crash reporting is enabled (always false in debug)
    /// Can be overridden with SONORA_CRASH_REPORTING_ENABLED environment variable
    public private(set) var crashReportingEnabled: Bool = false
    
    /// Whether beta features are enabled
    /// Can be overridden with SONORA_BETA_FEATURES_ENABLED environment variable
    public private(set) var betaFeaturesEnabled: Bool = false
    
    /// Whether experimental features are enabled (debug only by default)
    /// Can be overridden with SONORA_EXPERIMENTAL_FEATURES_ENABLED environment variable
    public private(set) var experimentalFeaturesEnabled: Bool = false
    
    // MARK: - Development Tools
    
    /// Whether to show debug UI elements
    /// Can be overridden with SONORA_SHOW_DEBUG_UI environment variable
    public private(set) var showDebugUI: Bool = false
    
    /// Whether to use mock data for development
    /// Can be overridden with SONORA_USE_MOCK_DATA environment variable
    public private(set) var useMockData: Bool = false
    
    /// Whether to bypass network calls (uses mock responses)
    /// Can be overridden with SONORA_BYPASS_NETWORK environment variable
    public private(set) var bypassNetwork: Bool = false
    
    /// Whether to show performance metrics in UI
    /// Can be overridden with SONORA_SHOW_PERFORMANCE_METRICS environment variable
    public private(set) var showPerformanceMetrics: Bool = false
    
    /// Whether to enable network request logging
    /// Can be overridden with SONORA_LOG_NETWORK_REQUESTS environment variable
    public private(set) var logNetworkRequests: Bool = false
    
    /// Whether to simulate slow network conditions
    /// Can be overridden with SONORA_SIMULATE_SLOW_NETWORK environment variable
    public private(set) var simulateSlowNetwork: Bool = false
    
    /// Network delay simulation in seconds (only when simulateSlowNetwork is true)
    /// Can be overridden with SONORA_NETWORK_DELAY environment variable
    public private(set) var networkDelaySimulation: TimeInterval = 2.0
    
    // MARK: - App Store and Distribution
    
    /// Whether the app is running from App Store
    public var isAppStore: Bool {
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "receipt"
    }
    
    /// Whether the app is running from TestFlight
    public var isTestFlight: Bool {
        return Bundle.main.appStoreReceiptURL?.path.contains("sandboxReceipt") == true
    }
    
    /// Whether the app is running in development (not App Store or TestFlight)
    public var isDevelopment: Bool {
        return !isAppStore && !isTestFlight
    }
    
    /// App version string
    public var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// App build number
    public var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    /// Full version string (version + build)
    public var fullVersionString: String {
        return "\(appVersion) (\(buildNumber))"
    }
    
    // MARK: - Device Information
    
    /// Device model identifier
    public var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String(validatingCString: ptr)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    /// iOS version
    public var iosVersion: String {
        let ver = ProcessInfo.processInfo.operatingSystemVersion
        return "\(ver.majorVersion).\(ver.minorVersion).\(ver.patchVersion)"
    }
    
    /// Whether device supports Dynamic Island
    public var supportsDynamicIsland: Bool {
        return deviceModel.hasPrefix("iPhone15") || // iPhone 14 Pro series
               deviceModel.hasPrefix("iPhone16")    // iPhone 15 Pro series and newer
    }
    
    /// Whether device supports Live Activities
    public var supportsLiveActivities: Bool {
        if #available(iOS 16.1, *) {
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Configuration Loading
    
    private func loadConfiguration() {
        // Detect build configuration
        #if DEBUG
        buildConfiguration = .debug
        #elseif TESTING
        buildConfiguration = .testing
        #else
        buildConfiguration = .release
        #endif
        
        // Override from environment if specified
        if let configString = ProcessInfo.processInfo.environment["SONORA_BUILD_CONFIG"],
           let config = BuildConfiguration(rawValue: configString) {
            buildConfiguration = config
        }
        
        // Logging Configuration
        if let consoleString = ProcessInfo.processInfo.environment["SONORA_LOG_TO_CONSOLE"],
           let console = Bool(consoleString) {
            logToConsole = console
        } else {
            // Default behavior: always log to console in debug, optional in release
            logToConsole = isDebug
        }
        
        if let fileString = ProcessInfo.processInfo.environment["SONORA_LOG_TO_FILE"],
           let file = Bool(fileString) {
            logToFile = file
        } else {
            // Default behavior: log to file in release builds
            logToFile = isRelease
        }
        
        if let systemString = ProcessInfo.processInfo.environment["SONORA_LOG_TO_SYSTEM"],
           let system = Bool(systemString) {
            logToSystem = system
        }
        
        if let sizeString = ProcessInfo.processInfo.environment["SONORA_MAX_LOG_FILE_SIZE"],
           let size = Int64(sizeString) {
            maxLogFileSize = max(1024 * 1024, size) // Minimum 1MB
        }
        
        if let locationString = ProcessInfo.processInfo.environment["SONORA_LOG_INCLUDE_LOCATION"],
           let location = Bool(locationString) {
            logIncludeLocation = location
        } else {
            logIncludeLocation = isDebug
        }
        
        if let timestampString = ProcessInfo.processInfo.environment["SONORA_LOG_INCLUDE_TIMESTAMP"],
           let timestamp = Bool(timestampString) {
            logIncludeTimestamp = timestamp
        }
        
        if let colorsString = ProcessInfo.processInfo.environment["SONORA_LOG_USE_COLORS"],
           let colors = Bool(colorsString) {
            logUseColors = colors
        } else {
            logUseColors = isDebug
        }
        
        // Feature Toggles
        if let liveActivitiesString = ProcessInfo.processInfo.environment["SONORA_LIVE_ACTIVITIES_ENABLED"],
           let liveActivities = Bool(liveActivitiesString) {
            liveActivitiesEnabled = liveActivities && supportsLiveActivities
        } else {
            liveActivitiesEnabled = supportsLiveActivities
        }
        
        if let dynamicIslandString = ProcessInfo.processInfo.environment["SONORA_DYNAMIC_ISLAND_ENABLED"],
           let dynamicIsland = Bool(dynamicIslandString) {
            dynamicIslandEnabled = dynamicIsland && supportsDynamicIsland
        } else {
            dynamicIslandEnabled = supportsDynamicIsland
        }
        
        if let backgroundString = ProcessInfo.processInfo.environment["SONORA_BACKGROUND_RECORDING_ENABLED"],
           let background = Bool(backgroundString) {
            backgroundRecordingEnabled = background
        }
        
        if let pushString = ProcessInfo.processInfo.environment["SONORA_PUSH_NOTIFICATIONS_ENABLED"],
           let push = Bool(pushString) {
            pushNotificationsEnabled = push
        }
        
        if let analyticsString = ProcessInfo.processInfo.environment["SONORA_ANALYTICS_ENABLED"],
           let analytics = Bool(analyticsString) {
            // Never enable analytics in debug builds
            analyticsEnabled = analytics && isRelease
        } else {
            analyticsEnabled = isRelease && !isDevelopment
        }
        
        if let crashString = ProcessInfo.processInfo.environment["SONORA_CRASH_REPORTING_ENABLED"],
           let crash = Bool(crashString) {
            // Never enable crash reporting in debug builds
            crashReportingEnabled = crash && isRelease
        } else {
            crashReportingEnabled = isRelease && !isDevelopment
        }
        
        if let betaString = ProcessInfo.processInfo.environment["SONORA_BETA_FEATURES_ENABLED"],
           let beta = Bool(betaString) {
            betaFeaturesEnabled = beta
        } else {
            betaFeaturesEnabled = isTestFlight || isDevelopment
        }
        
        if let experimentalString = ProcessInfo.processInfo.environment["SONORA_EXPERIMENTAL_FEATURES_ENABLED"],
           let experimental = Bool(experimentalString) {
            experimentalFeaturesEnabled = experimental
        } else {
            experimentalFeaturesEnabled = isDebug
        }
        
        // Development Tools (debug only by default)
        if let debugUIString = ProcessInfo.processInfo.environment["SONORA_SHOW_DEBUG_UI"],
           let debugUI = Bool(debugUIString) {
            showDebugUI = debugUI && (isDebug || isDevelopment)
        } else {
            showDebugUI = isDebug
        }
        
        if let mockDataString = ProcessInfo.processInfo.environment["SONORA_USE_MOCK_DATA"],
           let mockData = Bool(mockDataString) {
            useMockData = mockData && (isDebug || isTesting)
        } else {
            useMockData = isTesting
        }
        
        if let bypassString = ProcessInfo.processInfo.environment["SONORA_BYPASS_NETWORK"],
           let bypass = Bool(bypassString) {
            bypassNetwork = bypass && (isDebug || isTesting)
        } else {
            bypassNetwork = isTesting
        }
        
        if let metricsString = ProcessInfo.processInfo.environment["SONORA_SHOW_PERFORMANCE_METRICS"],
           let metrics = Bool(metricsString) {
            showPerformanceMetrics = metrics && (isDebug || isDevelopment)
        } else {
            showPerformanceMetrics = isDebug
        }
        
        if let logNetworkString = ProcessInfo.processInfo.environment["SONORA_LOG_NETWORK_REQUESTS"],
           let logNetwork = Bool(logNetworkString) {
            logNetworkRequests = logNetwork
        } else {
            logNetworkRequests = isDebug
        }
        
        if let slowNetworkString = ProcessInfo.processInfo.environment["SONORA_SIMULATE_SLOW_NETWORK"],
           let slowNetwork = Bool(slowNetworkString) {
            simulateSlowNetwork = slowNetwork && isDebug
        }
        
        if let delayString = ProcessInfo.processInfo.environment["SONORA_NETWORK_DELAY"],
           let delay = TimeInterval(delayString) {
            networkDelaySimulation = max(0.1, delay)
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if a feature is enabled
    public func isFeatureEnabled(_ feature: String) -> Bool {
        switch feature.lowercased() {
        case "liveactivities", "live_activities":
            return liveActivitiesEnabled
        case "dynamicisland", "dynamic_island":
            return dynamicIslandEnabled
        case "backgroundrecording", "background_recording":
            return backgroundRecordingEnabled
        case "pushnotifications", "push_notifications":
            return pushNotificationsEnabled
        case "analytics":
            return analyticsEnabled
        case "crashreporting", "crash_reporting":
            return crashReportingEnabled
        case "betafeatures", "beta_features":
            return betaFeaturesEnabled
        case "experimentalfeatures", "experimental_features":
            return experimentalFeaturesEnabled
        default:
            return false
        }
    }
    
    /// Get environment information for debugging
    public var debugDescription: String {
        return """
        Environment Configuration:
        - Build: \(buildConfiguration.displayName)
        - Version: \(fullVersionString)
        - Device: \(deviceModel)
        - iOS: \(iosVersion)
        - Distribution: \(isAppStore ? "App Store" : isTestFlight ? "TestFlight" : "Development")
        - Live Activities: \(liveActivitiesEnabled) (supported: \(supportsLiveActivities))
        - Dynamic Island: \(dynamicIslandEnabled) (supported: \(supportsDynamicIsland))
        - Debug UI: \(showDebugUI)
        - Mock Data: \(useMockData)
        - Network Bypass: \(bypassNetwork)
        """
    }
    
    /// Force reload configuration (useful for testing)
    public func reloadConfiguration() {
        loadConfiguration()
    }
}
