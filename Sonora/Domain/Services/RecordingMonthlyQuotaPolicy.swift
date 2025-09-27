import Foundation

/// Default implementation of monthly recording limits.
/// - Free users: 60 minutes/month (3600 seconds) for `.cloudAPI`.
/// - Pro users: no limit (returns `nil`).
public final class DefaultRecordingQuotaPolicy: RecordingQuotaPolicyProtocol, @unchecked Sendable {
    private let isProProvider: () -> Bool

    /// - Parameter isProProvider: Closure that returns current Pro entitlement state. Defaults to false.
    public init(isProProvider: @escaping () -> Bool = { false }) {
        self.isProProvider = isProProvider
    }

    public func monthlyLimit(for service: TranscriptionServiceType) -> TimeInterval? {
        if isProProvider() { return nil }
        switch service {
        case .cloudAPI:
            return 60 * 60 // 60 minutes in seconds
        }
    }
}

