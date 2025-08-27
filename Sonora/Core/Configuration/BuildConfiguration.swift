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
            return self == .debug || self == .testing
        }
        
        var isRelease: Bool {
            return self == .release
        }
        
        var displayName: String {
            return rawValue
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
        
        var isDistribution: Bool {
            return self == .testFlight || self == .appStore
        }
    }
    
    // MARK: - Build Properties
    
    /// Current build type (debug/release/testing)
    public private(set) var buildType: BuildType = .debug
    
    /// Current distribution type (development/TestFlight/App Store)
    public private(set) var distributionType: DistributionType = .development
    
    /// Whether the app is running in debug mode
    public var isDebug: Bool {
        return buildType.isDebug
    }
    
    /// Whether the app is running in release mode
    public var isRelease: Bool {
        return buildType.isRelease
    }
    
    /// Whether the app is running in testing mode
    public var isTesting: Bool {
        return buildType == .testing || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    /// Whether the app is running from App Store
    public var isAppStore: Bool {
        return distributionType == .appStore
    }
    
    /// Whether the app is running from TestFlight
    public var isTestFlight: Bool {
        return distributionType == .testFlight
    }
    
    /// Whether the app is running in development
    public var isDevelopment: Bool {
        return distributionType == .development
    }
    
    // MARK: - Bundle Information
    
    /// App bundle identifier
    public var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "unknown"
    }
    
    /// App version string (Marketing Version)
    public var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// App build number (Bundle Version)
    public var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    /// Full version string (version + build)
    public var fullVersionString: String {
        return "\(appVersion) (\(buildNumber))"
    }
    
    /// App display name
    public var appDisplayName: String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
               Bundle.main.infoDictionary?["CFBundleName"] as? String ??
               "Sonora"
    }
    
    /// Bundle executable name
    public var executableName: String {
        return Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? "Unknown"
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
        return bundleIdentifier == productionBundleID
    }
    
    /// Whether current bundle ID is a test bundle
    public var isTestBundleID: Bool {
        return bundleIdentifier == testBundleID || bundleIdentifier == uiTestBundleID
    }
    
    /// Whether bundle ID suggests development build
    public var isDevelopmentBundleID: Bool {
        return bundleIdentifier.contains(".dev") || 
               bundleIdentifier.contains(".debug") ||
               bundleIdentifier.contains(".staging") ||
               bundleIdentifier != productionBundleID
    }
    
    // MARK: - Device Information
    
    /// Device model identifier
    public var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    /// iOS version
    public var iosVersion: String {
        return UIDevice.current.systemVersion
    }
    
    /// Device name (user-defined)
    public var deviceName: String {
        return UIDevice.current.name
    }
    
    /// Device system name
    public var systemName: String {
        return UIDevice.current.systemName
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
    
    // MARK: - Code Signing Information
    
    /// Development team identifier
    public var developmentTeam: String? {
        return Bundle.main.infoDictionary?["DTSDKBuild"] as? String
    }
    
    /// Code signing identity
    public var codeSigningIdentity: String? {
        // Attempt to read from embedded provisioning profile
        return getProvisioningProfileInfo()!["TeamIdentifier"] as? String
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
        return !isDevelopmentSigned && !isDevelopment
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
        return """
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
