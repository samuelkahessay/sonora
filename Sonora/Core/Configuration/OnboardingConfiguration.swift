import Foundation

/// Configuration for onboarding flow state management
/// Handles persistence of onboarding completion and provides access to onboarding status
@MainActor
final class OnboardingConfiguration: ObservableObject {
    
    // MARK: - Singleton
    static let shared = OnboardingConfiguration()
    
    // MARK: - UserDefaults Keys
    private enum UserDefaultsKey {
        static let hasCompletedOnboarding = "app.onboarding.hasCompleted"
        static let onboardingVersion = "app.onboarding.version"
        static let lastOnboardingDate = "app.onboarding.lastDate"
    }
    
    // MARK: - Constants
    /// Current onboarding version - increment if onboarding flow changes significantly
    private let currentOnboardingVersion = 1
    
    // MARK: - Published Properties
    @Published var hasCompletedOnboarding: Bool = false
    @Published var shouldShowOnboarding: Bool = false
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Initialization
    private init() {
        loadOnboardingState()
        print("📋 OnboardingConfiguration: Initialized (completed: \(hasCompletedOnboarding))")
    }
    
    // MARK: - Public Methods
    
    /// Check if onboarding should be shown based on completion status and version
    func shouldShowOnboardingFlow() -> Bool {
        return !hasCompletedOnboarding || needsOnboardingUpdate()
    }
    
    /// Mark onboarding as completed
    func markOnboardingCompleted() {
        hasCompletedOnboarding = true
        shouldShowOnboarding = false
        
        userDefaults.set(true, forKey: UserDefaultsKey.hasCompletedOnboarding)
        userDefaults.set(currentOnboardingVersion, forKey: UserDefaultsKey.onboardingVersion)
        userDefaults.set(Date(), forKey: UserDefaultsKey.lastOnboardingDate)
        
        objectWillChange.send()
        print("✅ OnboardingConfiguration: Onboarding marked as completed (version \(currentOnboardingVersion))")
    }
    
    /// Force show onboarding (for Settings "View Onboarding" option)
    func forceShowOnboarding() {
        shouldShowOnboarding = true
        objectWillChange.send()
        print("🔄 OnboardingConfiguration: Forced onboarding display")
    }
    
    /// Reset onboarding state (useful for testing or troubleshooting)
    func resetOnboardingState() {
        hasCompletedOnboarding = false
        shouldShowOnboarding = true
        
        userDefaults.removeObject(forKey: UserDefaultsKey.hasCompletedOnboarding)
        userDefaults.removeObject(forKey: UserDefaultsKey.onboardingVersion)
        userDefaults.removeObject(forKey: UserDefaultsKey.lastOnboardingDate)
        
        objectWillChange.send()
        print("🔄 OnboardingConfiguration: Onboarding state reset")
    }
    
    /// Get onboarding completion date for debugging/analytics
    var onboardingCompletionDate: Date? {
        return userDefaults.object(forKey: UserDefaultsKey.lastOnboardingDate) as? Date
    }
    
    /// Get completed onboarding version
    var completedOnboardingVersion: Int {
        return userDefaults.integer(forKey: UserDefaultsKey.onboardingVersion)
    }
    
    // MARK: - Private Methods
    
    private func loadOnboardingState() {
        let completed = userDefaults.bool(forKey: UserDefaultsKey.hasCompletedOnboarding)
        hasCompletedOnboarding = completed
        shouldShowOnboarding = shouldShowOnboardingFlow()
        
        print("📋 OnboardingConfiguration: Loaded state (completed: \(completed), should show: \(shouldShowOnboarding))")
    }
    
    /// Check if onboarding needs to be shown due to version update
    private func needsOnboardingUpdate() -> Bool {
        let savedVersion = userDefaults.integer(forKey: UserDefaultsKey.onboardingVersion)
        let needsUpdate = savedVersion < currentOnboardingVersion
        
        if needsUpdate {
            print("📋 OnboardingConfiguration: Version update detected (saved: \(savedVersion), current: \(currentOnboardingVersion))")
        }
        
        return needsUpdate
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension OnboardingConfiguration {
    
    /// Get debug information about onboarding state
    var debugInfo: String {
        return """
        OnboardingConfiguration Debug Info:
        - hasCompletedOnboarding: \(hasCompletedOnboarding)
        - shouldShowOnboarding: \(shouldShowOnboarding)
        - currentVersion: \(currentOnboardingVersion)
        - savedVersion: \(completedOnboardingVersion)
        - completionDate: \(onboardingCompletionDate?.description ?? "none")
        - needsUpdate: \(needsOnboardingUpdate())
        """
    }
    
    /// Force reset for testing
    func debugResetForTesting() {
        resetOnboardingState()
        print("🧪 OnboardingConfiguration: Debug reset completed")
    }
}
#endif