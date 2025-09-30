import Foundation

// MARK: - Environment section models (pure, Sendable)

struct LoggingSettings: Sendable {
    let logToConsole: Bool
    let logToFile: Bool
    let logToSystem: Bool
    let maxLogFileSize: Int64
    let logIncludeLocation: Bool
    let logIncludeTimestamp: Bool
    let logUseColors: Bool

    static func resolved(env: [String: String], isDebug: Bool, isRelease: Bool) -> Self {
        // Defaults mirror Environment property initializers + conditional defaults in loader
        var logToConsole = isDebug
        if let s = env["SONORA_LOG_TO_CONSOLE"], let v = Bool(s) { logToConsole = v }

        var logToFile = isRelease
        if let s = env["SONORA_LOG_TO_FILE"], let v = Bool(s) { logToFile = v }

        var logToSystem = true
        if let s = env["SONORA_LOG_TO_SYSTEM"], let v = Bool(s) { logToSystem = v }

        var maxLogFileSize: Int64 = 10 * 1_024 * 1_024
        if let s = env["SONORA_MAX_LOG_FILE_SIZE"], let v = Int64(s) { maxLogFileSize = max(1_024 * 1_024, v) }

        var logIncludeLocation = isDebug
        if let s = env["SONORA_LOG_INCLUDE_LOCATION"], let v = Bool(s) { logIncludeLocation = v }

        var logIncludeTimestamp = true
        if let s = env["SONORA_LOG_INCLUDE_TIMESTAMP"], let v = Bool(s) { logIncludeTimestamp = v }

        var logUseColors = isDebug
        if let s = env["SONORA_LOG_USE_COLORS"], let v = Bool(s) { logUseColors = v }

        return Self(
            logToConsole: logToConsole,
            logToFile: logToFile,
            logToSystem: logToSystem,
            maxLogFileSize: maxLogFileSize,
            logIncludeLocation: logIncludeLocation,
            logIncludeTimestamp: logIncludeTimestamp,
            logUseColors: logUseColors
        )
    }
}

struct FeatureToggles: Sendable {
    let liveActivitiesEnabled: Bool
    let dynamicIslandEnabled: Bool
    let backgroundRecordingEnabled: Bool
    let pushNotificationsEnabled: Bool
    let analyticsEnabled: Bool
    let crashReportingEnabled: Bool
    let betaFeaturesEnabled: Bool
    let experimentalFeaturesEnabled: Bool

    static func resolved(
        env: [String: String],
        isDebug: Bool,
        isRelease: Bool,
        isTestFlight: Bool,
        isDevelopment: Bool,
        supportsLiveActivities: Bool,
        supportsDynamicIsland: Bool
    ) -> Self {
        var liveActivitiesEnabled = supportsLiveActivities
        if let s = env["SONORA_LIVE_ACTIVITIES_ENABLED"], let v = Bool(s) { liveActivitiesEnabled = v && supportsLiveActivities }

        var dynamicIslandEnabled = supportsDynamicIsland
        if let s = env["SONORA_DYNAMIC_ISLAND_ENABLED"], let v = Bool(s) { dynamicIslandEnabled = v && supportsDynamicIsland }

        var backgroundRecordingEnabled = true
        if let s = env["SONORA_BACKGROUND_RECORDING_ENABLED"], let v = Bool(s) { backgroundRecordingEnabled = v }

        var pushNotificationsEnabled = false
        if let s = env["SONORA_PUSH_NOTIFICATIONS_ENABLED"], let v = Bool(s) { pushNotificationsEnabled = v }

        var analyticsEnabled = isRelease && !isDevelopment
        if let s = env["SONORA_ANALYTICS_ENABLED"], let v = Bool(s) { analyticsEnabled = v && isRelease }

        var crashReportingEnabled = isRelease && !isDevelopment
        if let s = env["SONORA_CRASH_REPORTING_ENABLED"], let v = Bool(s) { crashReportingEnabled = v && isRelease }

        var betaFeaturesEnabled = isTestFlight || isDevelopment
        if let s = env["SONORA_BETA_FEATURES_ENABLED"], let v = Bool(s) { betaFeaturesEnabled = v }

        var experimentalFeaturesEnabled = isDebug
        if let s = env["SONORA_EXPERIMENTAL_FEATURES_ENABLED"], let v = Bool(s) { experimentalFeaturesEnabled = v }

        return Self(
            liveActivitiesEnabled: liveActivitiesEnabled,
            dynamicIslandEnabled: dynamicIslandEnabled,
            backgroundRecordingEnabled: backgroundRecordingEnabled,
            pushNotificationsEnabled: pushNotificationsEnabled,
            analyticsEnabled: analyticsEnabled,
            crashReportingEnabled: crashReportingEnabled,
            betaFeaturesEnabled: betaFeaturesEnabled,
            experimentalFeaturesEnabled: experimentalFeaturesEnabled
        )
    }
}

struct DevToolsOptions: Sendable {
    let showDebugUI: Bool
    let useMockData: Bool
    let bypassNetwork: Bool
    let showPerformanceMetrics: Bool
    let logNetworkRequests: Bool
    let simulateSlowNetwork: Bool
    let networkDelaySimulation: TimeInterval

    static func resolved(
        env: [String: String],
        isDebug: Bool,
        isTesting: Bool,
        isDevelopment: Bool
    ) -> Self {
        var showDebugUI = isDebug
        if let s = env["SONORA_SHOW_DEBUG_UI"], let v = Bool(s) { showDebugUI = v && (isDebug || isDevelopment) }

        var useMockData = isTesting
        if let s = env["SONORA_USE_MOCK_DATA"], let v = Bool(s) { useMockData = v && (isDebug || isTesting) }

        var bypassNetwork = isTesting
        if let s = env["SONORA_BYPASS_NETWORK"], let v = Bool(s) { bypassNetwork = v && (isDebug || isTesting) }

        var showPerformanceMetrics = isDebug
        if let s = env["SONORA_SHOW_PERFORMANCE_METRICS"], let v = Bool(s) { showPerformanceMetrics = v && (isDebug || isDevelopment) }

        var logNetworkRequests = isDebug
        if let s = env["SONORA_LOG_NETWORK_REQUESTS"], let v = Bool(s) { logNetworkRequests = v }

        var simulateSlowNetwork = false
        if let s = env["SONORA_SIMULATE_SLOW_NETWORK"], let v = Bool(s) { simulateSlowNetwork = v && isDebug }

        var networkDelaySimulation: TimeInterval = 2.0
        if let s = env["SONORA_NETWORK_DELAY"], let v = TimeInterval(s) { networkDelaySimulation = max(0.1, v) }

        return Self(
            showDebugUI: showDebugUI,
            useMockData: useMockData,
            bypassNetwork: bypassNetwork,
            showPerformanceMetrics: showPerformanceMetrics,
            logNetworkRequests: logNetworkRequests,
            simulateSlowNetwork: simulateSlowNetwork,
            networkDelaySimulation: networkDelaySimulation
        )
    }
}
