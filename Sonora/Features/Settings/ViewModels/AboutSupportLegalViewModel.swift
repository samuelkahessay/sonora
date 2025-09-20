import Foundation

@MainActor
final class AboutSupportLegalViewModel: ObservableObject {
    private let systemNavigator: any SystemNavigator
    private let logger: any LoggerProtocol

    let appVersion: String
    let buildNumber: String

    private let supportURL = URL(string: "https://samuelkahessay.github.io/sonora/support.html")!
    private let privacyURL = URL(string: "https://samuelkahessay.github.io/sonora/privacy-policy.html")!
    private let termsURL = URL(string: "https://samuelkahessay.github.io/sonora/terms-of-service.html")!

    init(resolver: Resolver? = nil) {
        let resolved = resolver ?? DIContainer.shared
        let container = (resolved as? DIContainer) ?? DIContainer.shared
        self.systemNavigator = resolved.resolve((any SystemNavigator).self) ?? container.systemNavigator()
        self.logger = resolved.resolve((any LoggerProtocol).self) ?? container.logger()
        self.appVersion = BuildConfiguration.shared.appVersion
        self.buildNumber = BuildConfiguration.shared.buildNumber
    }

    func openSupport() {
        logger.debug("Settings: open support", category: .viewModel, context: nil)
        systemNavigator.open(supportURL, completion: nil)
    }

    func openPrivacyPolicy() {
        logger.debug("Settings: open privacy policy", category: .viewModel, context: nil)
        systemNavigator.open(privacyURL, completion: nil)
    }

    func openTerms() {
        logger.debug("Settings: open terms of service", category: .viewModel, context: nil)
        systemNavigator.open(termsURL, completion: nil)
    }
}
