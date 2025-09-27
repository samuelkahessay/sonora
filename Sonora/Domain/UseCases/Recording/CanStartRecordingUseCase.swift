import Foundation

@MainActor
public protocol CanStartRecordingUseCaseProtocol {
    /// Returns allowed session duration (seconds) for the next recording if permitted.
    /// For unlimited services, returns nil. Throws RecordingQuotaError if not allowed.
    func execute(service: TranscriptionServiceType) async throws -> TimeInterval?
}

@MainActor
public final class CanStartRecordingUseCase: CanStartRecordingUseCaseProtocol {
    private let getRemainingMonthlyQuotaUseCase: any GetRemainingMonthlyQuotaUseCaseProtocol

    public init(getRemainingMonthlyQuotaUseCase: any GetRemainingMonthlyQuotaUseCaseProtocol) {
        self.getRemainingMonthlyQuotaUseCase = getRemainingMonthlyQuotaUseCase
    }

    public func execute(service: TranscriptionServiceType) async throws -> TimeInterval? {
        // Keep any upstream permission checks in the call chain intact.
        let remainingQuota = try await getRemainingMonthlyQuotaUseCase.execute()

        if remainingQuota == .infinity {
            // Pro user: no limits
            return nil
        }

        if remainingQuota <= 0 {
            throw RecordingQuotaError.limitReached(remaining: 0)
        }

        // Allow up to remaining monthly time
        return remainingQuota
    }
}
