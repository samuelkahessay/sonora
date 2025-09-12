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
        static let userName = "app.onboarding.userName"
    }
    
    // MARK: - Constants
    /// Current onboarding version - increment if onboarding flow changes significantly
    private let currentOnboardingVersion = 1
    
    // MARK: - Published Properties
    @Published var hasCompletedOnboarding: Bool = false
    @Published var shouldShowOnboarding: Bool = false
    @Published private(set) var currentUserName: String = "friend"
    
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
        
    // MARK: - User Name Management
    
    /// Save user name from onboarding
    func saveUserName(_ name: String) {
        let processedName = processUserName(name)
        userDefaults.set(processedName, forKey: UserDefaultsKey.userName)
        currentUserName = processedName
        print("📋 OnboardingConfiguration: User name saved: '\(processedName)'")
    }
    
    /// Get saved user name, fallback to "friend"
    func getUserName() -> String {
        print("📋 OnboardingConfiguration: Retrieved user name: '\(currentUserName)'")
        return currentUserName
    }
            
    /// Process and validate user name input
    private func processUserName(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle empty input
        if trimmed.isEmpty {
            return "friend"
        }
        
        // Truncate if too long (20 char limit for display)
        let processed = trimmed.count > 20 ? String(trimmed.prefix(20)) : trimmed
        
        // Capitalize first letter for consistency
        return processed.capitalized
    }
    
    // MARK: - Private Methods
    
    private func loadOnboardingState() {
        let completed = userDefaults.bool(forKey: UserDefaultsKey.hasCompletedOnboarding)
        hasCompletedOnboarding = completed
        shouldShowOnboarding = shouldShowOnboardingFlow()
        currentUserName = userDefaults.string(forKey: UserDefaultsKey.userName) ?? "friend"
        
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
