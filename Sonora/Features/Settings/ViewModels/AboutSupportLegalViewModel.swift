import Foundation

@MainActor
final class AboutSupportLegalViewModel: ObservableObject {
    private let systemNavigator: any SystemNavigator
    private let logger: any LoggerProtocol

    let appVersion: String
    let buildNumber: String

    private let supportURLString = "https://samuelkahessay.github.io/sonora/support.html"
    private let privacyURLString = "https://samuelkahessay.github.io/sonora/privacy-policy.html"
    private let termsURLString = "https://samuelkahessay.github.io/sonora/terms-of-service.html"

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
        guard let url = URL(string: supportURLString) else {
            logger.warning("Invalid support URL", category: .viewModel, context: nil, error: nil)
            return
        }
        systemNavigator.open(url, completion: nil)
    }

    func openPrivacyPolicy() {
        logger.debug("Settings: open privacy policy", category: .viewModel, context: nil)
        guard let url = URL(string: privacyURLString) else {
            logger.warning("Invalid privacy URL", category: .viewModel, context: nil, error: nil)
            return
        }
        systemNavigator.open(url, completion: nil)
    }

    func openTerms() {
        logger.debug("Settings: open terms of service", category: .viewModel, context: nil)
        guard let url = URL(string: termsURLString) else {
            logger.warning("Invalid terms URL", category: .viewModel, context: nil, error: nil)
            return
        }
        systemNavigator.open(url, completion: nil)
    }
}
