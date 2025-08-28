import Foundation

@MainActor
protocol SystemNavigator {
    func open(_ url: URL, completion: ((Bool) -> Void)?)
    func openSettings(completion: ((Bool) -> Void)?)
}

