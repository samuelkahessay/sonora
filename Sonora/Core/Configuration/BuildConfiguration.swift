import Foundation
import UIKit

/// Build configuration detection and bundle information management
/// Provides comprehensive build environment detection and app metadata access
public final class BuildConfiguration {

    // MARK: - Singleton

    public static let shared = BuildConfiguration()

    private init() {
        // Initialize build configuration detection
        detectBuildEnvironment()
    }

    // MARK: - Build Environment Types

    public enum BuildType: String, CaseIterable {
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

    public enum DistributionType: String, CaseIterable {
        case development = "Development"
        case testFlight = "TestFlight"
        case appStore = "AppStore"

        var displayName: String {
            switch self {
            case .development:
                return "Development"
            case .testFlight:
                return "TestFlight"
            case .appStore:
                return "App Store"
            }
        }
    }

    // MARK: - Build Properties

    /// Current build type (debug/release/testing)
    public private(set) var buildType: BuildType = .debug

    /// Current distribution type (development/TestFlight/App Store)
    public private(set) var distributionType: DistributionType = .development

    /// Whether the app is running in debug mode
    public var isDebug: Bool {
        buildType.isDebug
    }

    /// Whether the app is running in release mode
    public var isRelease: Bool {
        buildType.isRelease
    }

    /// Whether the app is running in testing mode
    public var isTesting: Bool {
        buildType == .testing || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Whether the app is running from App Store
    public var isAppStore: Bool {
        distributionType == .appStore
    }

    /// Whether the app is running from TestFlight
    public var isTestFlight: Bool {
        distributionType == .testFlight
    }

    /// Whether the app is running in development
    public var isDevelopment: Bool {
        distributionType == .development
    }

    // MARK: - Bundle Information

    /// App bundle identifier
    public var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    /// App version string (Marketing Version)
    public var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// App build number (Bundle Version)
    public var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    /// Full version string (version + build)
    public var fullVersionString: String {
        "\(appVersion) (\(buildNumber))"
    }

    /// App display name
    public var appDisplayName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
               Bundle.main.infoDictionary?["CFBundleName"] as? String ??
               "Sonora"
    }

    /// Bundle executable name
    public var executableName: String {
        Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? "Unknown"
    }

    // MARK: - Bundle Identifier Validation

    /// Production bundle identifier
    public let productionBundleID = "com.samuelkahessay.Sonora"

    /// Test bundle identifier
    public let testBundleID = "com.samuelkahessay.SonoraTests"

    /// UI Test bundle identifier
    public let uiTestBundleID = "com.samuelkahessay.SonoraUITests"

    /// Whether current bundle ID matches production
    public var isProductionBundleID: Bool {
        bundleIdentifier == productionBundleID
    }

    /// Whether current bundle ID is a test bundle
    public var isTestBundleID: Bool {
        bundleIdentifier == testBundleID || bundleIdentifier == uiTestBundleID
    }

    /// Whether bundle ID suggests development build
    public var isDevelopmentBundleID: Bool {
        bundleIdentifier.contains(".dev") ||
               bundleIdentifier.contains(".debug") ||
               bundleIdentifier.contains(".staging") ||
               bundleIdentifier != productionBundleID
    }

    // MARK: - Device Information

    /// Device model identifier
    public var deviceModel: String {
        // Avoid UIDevice to keep this usable from non-main contexts.
        // Build the identifier safely from the fixed-size CChar tuple.
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let v = element.value as? Int8, v != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(v))))
        }
        return identifier.isEmpty ? "Unknown" : identifier
    }

    /// iOS version
    public var iosVersion: String {
        // Use ProcessInfo to avoid main-actor UIDevice access
        let ver = ProcessInfo.processInfo.operatingSystemVersion
        return "\(ver.majorVersion).\(ver.minorVersion).\(ver.patchVersion)"
    }

    /// Device name (user-defined)
    @MainActor
    public var deviceName: String {
        UIDevice.current.name
    }

    /// Device system name
    @MainActor
    public var systemName: String {
        UIDevice.current.systemName
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

    // MARK: - Code Signing Information

    /// Development team identifier
    public var developmentTeam: String? {
        Bundle.main.infoDictionary?["DTSDKBuild"] as? String
    }

    /// Code signing identity
    public var codeSigningIdentity: String? {
        // Attempt to read from embedded provisioning profile
        getProvisioningProfileInfo()!["TeamIdentifier"] as? String
    }

    /// Whether app is code signed with development certificate
    public var isDevelopmentSigned: Bool {
        guard let profile = getProvisioningProfileInfo() else { return false }

        // Check if provisioning profile contains development certificates
        if let entitlements = profile["Entitlements"] as? [String: Any],
           let getTaskAllow = entitlements["get-task-allow"] as? Bool {
            return getTaskAllow // Development profiles have get-task-allow = true
        }

        return false
    }

    /// Whether app is code signed with distribution certificate
    public var isDistributionSigned: Bool {
        !isDevelopmentSigned && !isDevelopment
    }

    // MARK: - Build Detection Logic

    private func detectBuildEnvironment() {
        // Detect build type using compiler flags
        #if DEBUG
        buildType = isTesting ? .testing : .debug
        #else
        buildType = .release
        #endif

        // Override build type from environment if specified (useful for testing)
        if let buildTypeString = ProcessInfo.processInfo.environment["SONORA_BUILD_TYPE"],
           let type = BuildType(rawValue: buildTypeString) {
            buildType = type
        }

        // Detect distribution type
        distributionType = detectDistributionType()

        // Log build configuration
        logBuildConfiguration()
    }

    private func detectDistributionType() -> DistributionType {
        // Check for App Store receipt
        if let receiptURL = Bundle.main.appStoreReceiptURL {
            let receiptPath = receiptURL.path
            let receiptFilename = receiptURL.lastPathComponent

            // App Store builds have "receipt" file
            if receiptFilename == "receipt" && !receiptPath.contains("sandboxReceipt") {
                return .appStore
            }

            // TestFlight builds have "sandboxReceipt" in path
            if receiptPath.contains("sandboxReceipt") {
                return .testFlight
            }
        }

        // Check provisioning profile for additional clues
        if let provisioningInfo = getProvisioningProfileInfo() {
            // TestFlight builds often have specific provisioning profile characteristics
            if let provisioningName = provisioningInfo["Name"] as? String {
                if provisioningName.contains("TestFlight") ||
                   provisioningName.contains("Beta") ||
                   provisioningName.contains("AdHoc") {
                    return .testFlight
                }
            }

            // Check for enterprise distribution
            if let entitlements = provisioningInfo["Entitlements"] as? [String: Any] {
                if entitlements["beta-reports-active"] as? Bool == true {
                    return .testFlight
                }
            }
        }

        // Check bundle ID patterns
        if isDevelopmentBundleID || isTestBundleID {
            return .development
        }

        // If we're in debug mode but have production bundle ID, likely development
        if isDebug && isProductionBundleID {
            return .development
        }

        // Default to development for debug builds, otherwise check signing
        if isDebug {
            return .development
        } else if isDevelopmentSigned {
            return .development
        } else {
            return .appStore
        }
    }

    private func getProvisioningProfileInfo() -> [String: Any]? {
        // Read embedded provisioning profile
        guard let profilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            return nil
        }

        guard let profileData = NSData(contentsOfFile: profilePath) else {
            return nil
        }

        // Parse the provisioning profile (simplified parsing)
        let dataString = String(data: profileData as Data, encoding: .ascii) ?? ""

        // Look for plist data between <?xml and </plist>
        let startPattern = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
        let endPattern = "</plist>"

        guard let startRange = dataString.range(of: startPattern),
              let endRange = dataString.range(of: endPattern) else {
            return nil
        }

        let plistString = String(dataString[startRange.lowerBound..<endRange.upperBound])

        guard let plistData = plistString.data(using: .utf8) else {
            return nil
        }

        do {
            let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)
            return plist as? [String: Any]
        } catch {
            return nil
        }
    }

    private func logBuildConfiguration() {
        print("🔧 BuildConfiguration:")
        print("   Build Type: \(buildType.displayName)")
        print("   Distribution: \(distributionType.displayName)")
        print("   Version: \(fullVersionString)")
        print("   Bundle ID: \(bundleIdentifier)")
        print("   Device: \(deviceModel)")
        print("   iOS: \(iosVersion)")
        print("   Supports Live Activities: \(supportsLiveActivities)")
        print("   Supports Dynamic Island: \(supportsDynamicIsland)")
        print("   Development Signed: \(isDevelopmentSigned)")
        print("   Production Bundle: \(isProductionBundleID)")
    }

    // MARK: - Public Methods

    /// Get configuration summary for debugging
    public var debugDescription: String {
        """
        Build Configuration:
        - Type: \(buildType.displayName)
        - Distribution: \(distributionType.displayName)
        - Version: \(fullVersionString)
        - Bundle ID: \(bundleIdentifier)
        - Device: \(deviceModel) (\(iosVersion))
        - Capabilities: Live Activities(\(supportsLiveActivities)), Dynamic Island(\(supportsDynamicIsland))
        - Signing: \(isDevelopmentSigned ? "Development" : "Distribution")
        - Environment: \(isDebug ? "Debug" : "Release")
        """
    }

    /// Validate build configuration consistency
    public func validateConfiguration() -> [String] {
        var warnings: [String] = []

        // Check for inconsistencies
        if isRelease && isDevelopmentSigned {
            warnings.append("Release build with development signing")
        }

        if isAppStore && !isProductionBundleID {
            warnings.append("App Store distribution with non-production bundle ID")
        }

        if isDebug && distributionType == .appStore {
            warnings.append("Debug build detected as App Store distribution")
        }

        if isDevelopment && buildType == .release {
            warnings.append("Development distribution with release build type")
        }

        return warnings
    }

    /// Force re-detection of build environment (useful for testing)
    public func redetectBuildEnvironment() {
        detectBuildEnvironment()
    }

    /// Check if running in simulator
    public var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// Get appropriate configuration suffix for current build
    public var configurationSuffix: String {
        switch (buildType, distributionType) {
        case (.debug, .development):
            return "-dev"
        case (.release, .testFlight):
            return "-beta"
        case (.release, .appStore):
            return ""
        case (.testing, _):
            return "-test"
        default:
            return "-unknown"
        }
    }
}

// BuildConfiguration is read-only after init and used app-wide; mark unchecked.
extension BuildConfiguration: @unchecked Sendable {}
