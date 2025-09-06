import Foundation
import os
import os.signpost

@MainActor
enum Signpost {
    @available(iOS 15.0, *)
    private static let _signposter = OSSignposter()

    // Store interval states for cross-point intervals
    @available(iOS 15.0, *)
    private static var appStartupState: OSSignpostIntervalState?

    // MARK: - App Startup Interval
    static func beginAppStartup() {
        if #available(iOS 15.0, *) {
            appStartupState = _signposter.beginInterval("AppStartup")
        }
    }

    static func endAppStartup() {
        if #available(iOS 15.0, *) {
            if let state = appStartupState {
                _signposter.endInterval("AppStartup", state)
                appStartupState = nil
            }
        }
    }

    // MARK: - Utility Intervals
    @discardableResult
    static func beginInterval(_ name: StaticString) -> Any? {
        if #available(iOS 15.0, *) {
            return _signposter.beginInterval(name)
        }
        return nil
    }

    static func endInterval(_ name: StaticString, _ state: Any?) {
        if #available(iOS 15.0, *), let s = state as? OSSignpostIntervalState {
            _signposter.endInterval(name, s)
        }
    }

    static func event(_ name: StaticString) {
        if #available(iOS 15.0, *) {
            _signposter.emitEvent(name)
        }
    }
}
