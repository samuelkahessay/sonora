import Testing
@testable import Sonora

struct RecordingQuotaPolicyTests {
    @Test func testMonthlyLimit_CloudAPI_Is60Minutes() {
        let policy = DefaultRecordingQuotaPolicy()
        let limit = policy.monthlyLimit(for: .cloudAPI)
        #expect(limit == 3_600)
    }
}
