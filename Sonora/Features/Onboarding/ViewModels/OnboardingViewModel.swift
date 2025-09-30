import Foundation
import SwiftUI

/// Onboarding page types
enum OnboardingPage: String, CaseIterable {
    case nameEntry = "nameEntry"
    case howItWorks = "howItWorks"
    case firstRecording = "firstRecording"

    var title: String {
        switch self {
        case .nameEntry:
            return "Welcome to Sonora"
        case .howItWorks:
            return "How It Works"
        case .firstRecording:
            return "Ready to Start"
        }
    }

    var iconName: String {
        switch self {
        case .nameEntry:
            return "waveform.badge.mic"
        case .howItWorks:
            return "lightbulb.circle"
        case .firstRecording:
            return "mic.badge.plus"
        }
    }

    var primaryButtonTitle: String? {
        switch self {
        case .nameEntry:
            return "Continue"
        case .howItWorks:
            return "Continue"
        case .firstRecording:
            return "Start Recording"
        }
    }

    var description: String {
        switch self {
        case .nameEntry:
            return "What should I call you?"
        case .howItWorks:
            return "Transform your voice into actionable insights with privacy-first AI voice memos."
        case .firstRecording:
            return "Let's create your first voice memo together."
        }
    }

    var detailedPoints: [String] {
        switch self {
        case .nameEntry:
            return []
        case .howItWorks:
            return [
                "1. Tap record and speak naturally",
                "2. Automatic transcription & analysis",
                "3. Get distilled insights & summaries",
                "All processing respects your privacy"
            ]
        case .firstRecording:
            return []
        }
    }
}

/// ViewModel for managing onboarding flow
@MainActor
final class OnboardingViewModel: ObservableObject, ErrorHandling {

    // MARK: - Dependencies
    private let onboardingConfiguration: OnboardingConfiguration

    // MARK: - Published Properties
    @Published var currentPage: OnboardingPage = .nameEntry
    @Published var currentPageIndex: Int = 0
    @Published var userName: String = ""
    @Published var error: SonoraError?
    @Published var isLoading: Bool = false

    // MARK: - Constants
    private let pages = OnboardingPage.allCases

    // MARK: - Computed Properties

    var totalPages: Int {
        pages.count
    }

    var isFirstPage: Bool {
        currentPageIndex == 0
    }

    var isLastPage: Bool {
        currentPageIndex == totalPages - 1
    }

    var canGoNext: Bool {
        switch currentPage {
        case .nameEntry:
            // Can always proceed (empty name defaults to "friend")
            return true
        case .howItWorks:
            return true
        case .firstRecording:
            return true
        }
    }

    var progressPercentage: Double {
        Double(currentPageIndex + 1) / Double(totalPages)
    }

    // MARK: - Initialization

    init(
        onboardingConfiguration: OnboardingConfiguration
    ) {
        self.onboardingConfiguration = onboardingConfiguration

        // Load saved user name if available
        self.userName = onboardingConfiguration.getUserName()

        print("📋 OnboardingViewModel: Initialized")
    }

    // MARK: - Navigation Methods

    func goToNextPage() {
        guard !isLastPage else {
            completeOnboarding()
            return
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            currentPageIndex += 1
            currentPage = pages[currentPageIndex]
        }

        print("📋 OnboardingViewModel: Moved to page \(currentPageIndex): \(currentPage.rawValue)")
    }

    func goToPreviousPage() {
        guard !isFirstPage else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            currentPageIndex -= 1
            currentPage = pages[currentPageIndex]
        }

        print("📋 OnboardingViewModel: Moved to page \(currentPageIndex): \(currentPage.rawValue)")
    }

    func goToPage(_ page: OnboardingPage) {
        guard let index = pages.firstIndex(of: page) else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            currentPageIndex = index
            currentPage = page
        }

        print("📋 OnboardingViewModel: Jumped to page \(currentPageIndex): \(currentPage.rawValue)")
    }

    // MARK: - Permission Methods

    // MARK: - Personalization Methods

    func saveUserName(_ name: String) {
        let processedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        userName = processedName.isEmpty ? "friend" : processedName
        onboardingConfiguration.saveUserName(userName)
        print("📋 OnboardingViewModel: Saved user name: '\(userName)'")
    }

    func getPersonalizedGreeting() -> String {
        let name = onboardingConfiguration.getUserName()
        return "How was your day, \(name)?"
    }

    func startFirstRecording() {
        print("📋 OnboardingViewModel: Starting first recording")
        // This will be handled by the recording system
        completeOnboarding()
    }

    // MARK: - Completion Methods

    func skipOnboarding() {
        print("📋 OnboardingViewModel: Skipping onboarding")
        completeOnboarding()
    }

    func completeOnboarding() {
        print("📋 OnboardingViewModel: Completing onboarding")
        onboardingConfiguration.markOnboardingCompleted()
    }

    // MARK: - ErrorHandling Protocol

    func retryLastOperation() {
        clearError()

        // For the new simplified onboarding, just clear the error
        // No specific retry actions needed for the 3-screen flow
    }

    // MARK: - Utility Methods

    func resetUserName() {
        userName = ""
        onboardingConfiguration.saveUserName("")
        print("📋 OnboardingViewModel: Reset user name")
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension OnboardingViewModel {

    var debugInfo: String {
        return """
        OnboardingViewModel Debug Info:
        - currentPage: \(currentPage.rawValue) (\(currentPageIndex)/\(totalPages))
        - canGoNext: \(canGoNext)
        - progressPercentage: \(progressPercentage)
        - error: \(error?.localizedDescription ?? "none")
        """
    }
}
#endif
