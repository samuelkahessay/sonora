import Foundation
import UIKit

@MainActor
final class SystemNavigatorImpl: SystemNavigator {
    func open(_ url: URL, completion: ((Bool) -> Void)? = nil) {
        UIApplication.shared.open(url) { success in
            completion?(success)
        }
    }

    func openSettings(completion: ((Bool) -> Void)? = nil) {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            completion?(false)
            return
        }
        open(settingsURL, completion: completion)
    }
}
