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
            self == .debug || self == .testing
        }

        var isRelease: Bool {
            self == .release
        }

        var displayName: String {
            rawValue
        }
    }

    /// Current build configuration
    public private(set) var buildConfiguration: BuildConfiguration = .debug

    /// Whether the app is running in debug mode
    public var isDebug: Bool {
        buildConfiguration.isDebug
    }

    /// Whether the app is running in release mode
    public var isRelease: Bool {
        buildConfiguration.isRelease
    }

    /// Whether the app is running in testing mode
    public var isTesting: Bool {
        buildConfiguration == .testing || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
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
    public private(set) var maxLogFileSize: Int64 = 10 * 1_024 * 1_024

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
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "receipt"
    }

    /// Whether the app is running from TestFlight
    public var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.path.contains("sandboxReceipt") == true
    }

    /// Whether the app is running in development (not App Store or TestFlight)
    public var isDevelopment: Bool {
        !isAppStore && !isTestFlight
    }

    /// App version string
    public var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// App build number
    public var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    /// Full version string (version + build)
    public var fullVersionString: String {
        "\(appVersion) (\(buildNumber))"
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
        deviceModel.hasPrefix("iPhone15") || // iPhone 14 Pro series
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
        let env = ProcessInfo.processInfo.environment
        if let configString = env["SONORA_BUILD_CONFIG"], let config = BuildConfiguration(rawValue: configString) {
            buildConfiguration = config
        }

        // Resolve sections via pure helpers
        let logging = LoggingSettings.resolved(env: env, isDebug: isDebug, isRelease: isRelease)
        logToConsole = logging.logToConsole
        logToFile = logging.logToFile
        logToSystem = logging.logToSystem
        maxLogFileSize = logging.maxLogFileSize
        logIncludeLocation = logging.logIncludeLocation
        logIncludeTimestamp = logging.logIncludeTimestamp
        logUseColors = logging.logUseColors

        let features = FeatureToggles.resolved(
            env: env,
            isDebug: isDebug,
            isRelease: isRelease,
            isTestFlight: isTestFlight,
            isDevelopment: isDevelopment,
            supportsLiveActivities: supportsLiveActivities,
            supportsDynamicIsland: supportsDynamicIsland
        )
        liveActivitiesEnabled = features.liveActivitiesEnabled
        dynamicIslandEnabled = features.dynamicIslandEnabled
        backgroundRecordingEnabled = features.backgroundRecordingEnabled
        pushNotificationsEnabled = features.pushNotificationsEnabled
        analyticsEnabled = features.analyticsEnabled
        crashReportingEnabled = features.crashReportingEnabled
        betaFeaturesEnabled = features.betaFeaturesEnabled
        experimentalFeaturesEnabled = features.experimentalFeaturesEnabled

        let tools = DevToolsOptions.resolved(env: env, isDebug: isDebug, isTesting: isTesting, isDevelopment: isDevelopment)
        showDebugUI = tools.showDebugUI
        useMockData = tools.useMockData
        bypassNetwork = tools.bypassNetwork
        showPerformanceMetrics = tools.showPerformanceMetrics
        logNetworkRequests = tools.logNetworkRequests
        simulateSlowNetwork = tools.simulateSlowNetwork
        networkDelaySimulation = tools.networkDelaySimulation
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
        """
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
