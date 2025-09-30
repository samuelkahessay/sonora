import XCTest
@testable import Sonora

final class EnvironmentResolversTests: XCTestCase {

    func test_loggingSettings_defaults_debug() {
        let env: [String: String] = [:]
        let s = LoggingSettings.resolved(env: env, isDebug: true, isRelease: false)
        XCTAssertTrue(s.logToConsole)
        XCTAssertFalse(s.logToFile)
        XCTAssertTrue(s.logToSystem)
        XCTAssertEqual(s.maxLogFileSize, 10 * 1_024 * 1_024)
        XCTAssertTrue(s.logIncludeLocation)
        XCTAssertTrue(s.logIncludeTimestamp)
        XCTAssertTrue(s.logUseColors)
    }

    func test_loggingSettings_defaults_release() {
        let env: [String: String] = [:]
        let s = LoggingSettings.resolved(env: env, isDebug: false, isRelease: true)
        XCTAssertFalse(s.logToConsole)
        XCTAssertTrue(s.logToFile)
        XCTAssertTrue(s.logToSystem)
        XCTAssertEqual(s.maxLogFileSize, 10 * 1_024 * 1_024)
        XCTAssertFalse(s.logIncludeLocation)
        XCTAssertTrue(s.logIncludeTimestamp)
        XCTAssertFalse(s.logUseColors)
    }

    func test_loggingSettings_env_overrides() {
        let env: [String: String] = [
            "SONORA_LOG_TO_CONSOLE": "true",
            "SONORA_LOG_TO_FILE": "false",
            "SONORA_LOG_TO_SYSTEM": "false",
            "SONORA_MAX_LOG_FILE_SIZE": "1048576",
            "SONORA_LOG_INCLUDE_LOCATION": "true",
            "SONORA_LOG_INCLUDE_TIMESTAMP": "false",
            "SONORA_LOG_USE_COLORS": "true",
        ]
        let s = LoggingSettings.resolved(env: env, isDebug: false, isRelease: true)
        XCTAssertTrue(s.logToConsole)
        XCTAssertFalse(s.logToFile)
        XCTAssertFalse(s.logToSystem)
        XCTAssertEqual(s.maxLogFileSize, 1_048_576)
        XCTAssertTrue(s.logIncludeLocation)
        XCTAssertFalse(s.logIncludeTimestamp)
        XCTAssertTrue(s.logUseColors)
    }

    func test_featureToggles_support_gating() {
        let env: [String: String] = [
            "SONORA_LIVE_ACTIVITIES_ENABLED": "true",
            "SONORA_DYNAMIC_ISLAND_ENABLED": "true",
        ]
        let f = FeatureToggles.resolved(
            env: env,
            isDebug: false,
            isRelease: true,
            isTestFlight: false,
            isDevelopment: false,
            supportsLiveActivities: false, // gate off
            supportsDynamicIsland: false   // gate off
        )
        XCTAssertFalse(f.liveActivitiesEnabled)
        XCTAssertFalse(f.dynamicIslandEnabled)
    }

    func test_featureToggles_analytics_crash_release_only() {
        let enable: [String: String] = [
            "SONORA_ANALYTICS_ENABLED": "true",
            "SONORA_CRASH_REPORTING_ENABLED": "true",
        ]
        let rel = FeatureToggles.resolved(env: enable, isDebug: false, isRelease: true, isTestFlight: false, isDevelopment: false, supportsLiveActivities: true, supportsDynamicIsland: true)
        XCTAssertTrue(rel.analyticsEnabled)
        XCTAssertTrue(rel.crashReportingEnabled)

        let dbg = FeatureToggles.resolved(env: enable, isDebug: true, isRelease: false, isTestFlight: false, isDevelopment: true, supportsLiveActivities: true, supportsDynamicIsland: true)
        XCTAssertFalse(dbg.analyticsEnabled)
        XCTAssertFalse(dbg.crashReportingEnabled)
    }

    func test_devTools_defaults_and_overrides() {
        var env: [String: String] = [:]
        var tools = DevToolsOptions.resolved(env: env, isDebug: true, isTesting: false, isDevelopment: true)
        XCTAssertTrue(tools.showDebugUI)
        XCTAssertFalse(tools.useMockData)
        XCTAssertFalse(tools.bypassNetwork)
        XCTAssertTrue(tools.showPerformanceMetrics)
        XCTAssertTrue(tools.logNetworkRequests)
        XCTAssertFalse(tools.simulateSlowNetwork)
        XCTAssertEqual(tools.networkDelaySimulation, 2.0, accuracy: 0.0001)

        env = [
            "SONORA_SHOW_DEBUG_UI": "false",
            "SONORA_USE_MOCK_DATA": "true",
            "SONORA_BYPASS_NETWORK": "true",
            "SONORA_SHOW_PERFORMANCE_METRICS": "false",
            "SONORA_LOG_NETWORK_REQUESTS": "false",
            "SONORA_SIMULATE_SLOW_NETWORK": "true",
            "SONORA_NETWORK_DELAY": "0.05" // clamp to 0.1
        ]
        tools = DevToolsOptions.resolved(env: env, isDebug: true, isTesting: true, isDevelopment: true)
        XCTAssertFalse(tools.showDebugUI)
        XCTAssertTrue(tools.useMockData)
        XCTAssertTrue(tools.bypassNetwork)
        XCTAssertFalse(tools.showPerformanceMetrics)
        XCTAssertFalse(tools.logNetworkRequests)
        XCTAssertTrue(tools.simulateSlowNetwork)
        XCTAssertEqual(tools.networkDelaySimulation, 0.1, accuracy: 0.0001)
    }
}

