import Foundation
import SwiftUI

/// Onboarding page types
enum OnboardingPage: String, CaseIterable {
    case welcome = "welcome"
    case privacy = "privacy"
    case microphone = "microphone"
    case features = "features"
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Sonora"
        case .privacy:
            return "Your Data, Your Control"
        case .microphone:
            return "Enable Recording"
        case .features:
            return "Ready to Start"
        }
    }
    
    var iconName: String {
        switch self {
        case .welcome:
            return "waveform.badge.mic"
        case .privacy:
            return "lock.shield"
        case .microphone:
            return "mic"
        case .features:
            return "sparkles"
        }
    }
    
    var primaryButtonTitle: String? {
        switch self {
        case .welcome:
            return "Get Started"
        case .privacy:
            return "That Sounds Great"
        case .microphone:
            return "Allow Microphone"
        case .features:
            return "Start Using Sonora"
        }
    }
    
    var description: String {
        switch self {
        case .welcome:
            return "Transform your voice into actionable insights with privacy-first AI voice memos."
        case .privacy:
            return "Your recordings stay securely on your device. We only process them in the cloud when you explicitly choose to transcribe or analyze them."
        case .microphone:
            return "Sonora needs microphone access to record voice memos. We'll never record without your explicit action."
        case .features:
            return "You're all set! Record voice memos with background recording, Live Activities, and AI-powered insights."
        }
    }
    
    var detailedPoints: [String] {
        switch self {
        case .welcome:
            return [
                "Privacy-first voice memos",
                "AI transcription & analysis",
                "Background recording support",
                "Beautiful native iOS design"
            ]
        case .privacy:
            return [
                "Recordings stored locally on device",
                "Cloud processing only when you tap 'Transcribe'",
                "No tracking, no analytics, no compromises",
                "You control when your data leaves your device"
            ]
        case .microphone:
            return [
                "Required for recording voice memos",
                "Background recording with Live Activities",
                "Never accessed without your knowledge",
                "You can revoke permission anytime in Settings"
            ]
        case .features:
            return [
                "Daily cloud limit: 10 minutes",
                "Background recording with Live Activities",
                "AI transcription in 100+ languages",
                "Smart summaries, themes, and todos"
            ]
        }
    }
}

/// ViewModel for managing onboarding flow
@MainActor
final class OnboardingViewModel: ObservableObject, ErrorHandling {
    
    // MARK: - Dependencies
    private let requestMicrophonePermissionUseCase: RequestMicrophonePermissionUseCaseProtocol
    private let onboardingConfiguration: OnboardingConfiguration
    
    // MARK: - Published Properties
    @Published var currentPage: OnboardingPage = .welcome
    @Published var currentPageIndex: Int = 0
    @Published var isRequestingPermission: Bool = false
    @Published var microphonePermissionStatus: MicrophonePermissionStatus = .notDetermined
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
        case .microphone:
            // Can only proceed if permission is granted or denied (not undetermined)
            return microphonePermissionStatus != .notDetermined
        default:
            return true
        }
    }
    
    var progressPercentage: Double {
        Double(currentPageIndex + 1) / Double(totalPages)
    }
    
    // MARK: - Initialization
    
    init(
        requestMicrophonePermissionUseCase: RequestMicrophonePermissionUseCaseProtocol,
        onboardingConfiguration: OnboardingConfiguration
    ) {
        self.requestMicrophonePermissionUseCase = requestMicrophonePermissionUseCase
        self.onboardingConfiguration = onboardingConfiguration
        
        // Initialize microphone permission status
        updateMicrophonePermissionStatus()
        
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
    
    func requestMicrophonePermission() {
        print("📋 OnboardingViewModel: Requesting microphone permission")
        isRequestingPermission = true
        
        Task {
            let status = await requestMicrophonePermissionUseCase.execute()
            await MainActor.run {
                self.microphonePermissionStatus = status
                self.isRequestingPermission = false
                
                if status == .granted {
                    print("✅ OnboardingViewModel: Microphone permission granted")
                    // Auto-advance to next page on success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.goToNextPage()
                    }
                } else {
                    print("⚠️ OnboardingViewModel: Microphone permission not granted: \(status)")
                }
            }
        }
    }
    
    private func updateMicrophonePermissionStatus() {
        microphonePermissionStatus = MicrophonePermissionStatus.current()
        print("📋 OnboardingViewModel: Updated microphone status: \(microphonePermissionStatus)")
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
        
        // Retry based on current page context
        switch currentPage {
        case .microphone:
            requestMicrophonePermission()
        default:
            // For other pages, just clear the error
            break
        }
    }
    
    // MARK: - Utility Methods
    
    func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else {
            print("❌ OnboardingViewModel: Cannot open Settings")
            return
        }
        
        UIApplication.shared.open(settingsUrl)
        print("📋 OnboardingViewModel: Opened Settings app")
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension OnboardingViewModel {
    
    var debugInfo: String {
        return """
        OnboardingViewModel Debug Info:
        - currentPage: \(currentPage.rawValue) (\(currentPageIndex)/\(totalPages))
        - microphonePermissionStatus: \(microphonePermissionStatus)
        - isRequestingPermission: \(isRequestingPermission)
        - canGoNext: \(canGoNext)
        - progressPercentage: \(progressPercentage)
        - error: \(error?.localizedDescription ?? "none")
        """
    }
}
#endif
