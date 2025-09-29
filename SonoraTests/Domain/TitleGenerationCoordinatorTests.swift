import XCTest
import Combine
@testable import Sonora

@MainActor
final class TitleGenerationCoordinatorTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var memoRepository: MemoRepositoryImpl!
    private var transcriptionRepository: TranscriptionRepositoryImpl!
    private var jobRepository: AutoTitleJobRepositoryImpl!
    private var coordinator: TitleGenerationCoordinator!
    private var titleService: MockTitleService!
    private var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        let schema = Schema([
            MemoModel.self,
            TranscriptionModel.self,
            AnalysisResultModel.self,
            AutoTitleJobModel.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: configuration)
        context = ModelContext(container)

        transcriptionRepository = TranscriptionRepositoryImpl(context: context)
        jobRepository = AutoTitleJobRepositoryImpl(context: context)
        memoRepository = MemoRepositoryImpl(
            context: context,
            transcriptionRepository: transcriptionRepository,
            autoTitleJobRepository: jobRepository
        )

        titleService = MockTitleService()
        coordinator = TitleGenerationCoordinator(
            titleService: titleService,
            memoRepository: memoRepository,
            transcriptionRepository: transcriptionRepository,
            jobRepository: jobRepository,
            logger: Logger.shared
        )
    }

    override func tearDownWithError() throws {
        cancellables.removeAll()
        coordinator = nil
        titleService = nil
        memoRepository = nil
        jobRepository = nil
        transcriptionRepository = nil
        context = nil
        container = nil
    }

    func testFailureUpdatesMetrics() async throws {
        let memo = try makeTestMemo()
        transcriptionRepository.saveTranscriptionText("This is a transcript prepared for testing", for: memo.id)

        titleService.results = [.failure(TitleServiceError.networking(URLError(.timedOut)))]

        let expectation = XCTestExpectation(description: "Metrics reflect failure")
        coordinator.$metrics
            .dropFirst()
            .sink { metrics in
                if metrics.failedCount == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        coordinator.enqueue(memoId: memo.id)

        wait(for: [expectation], timeout: 2.0)

        let job = jobRepository.job(for: memo.id)
        XCTAssertEqual(job?.failureReason, .timeout)
        XCTAssertEqual(coordinator.metrics.failedCount, 1)
        XCTAssertTrue(coordinator.metrics.hasFailures)
    }

    func testAppDidBecomeActiveRequeuesMemoNeedingTitle() async throws {
        let memo = try makeTestMemo()
        transcriptionRepository.saveTranscriptionText("Another transcript for auto titling", for: memo.id)

        // Allow coordinator to pick up the memo and enqueue once.
        try await Task.sleep(nanoseconds: 200_000_000)

        jobRepository.deleteJob(for: memo.id)
        XCTAssertNil(jobRepository.job(for: memo.id))

        coordinator.appDidBecomeActive()

        let job = jobRepository.job(for: memo.id)
        XCTAssertNotNil(job)
    }

    func testStreamingUpdateReflectsInState() async throws {
        let memo = try makeTestMemo()
        transcriptionRepository.saveTranscriptionText("Streaming transcript for testing", for: memo.id)

        titleService.results = [
            .stream(partials: ["Weekly"], final: "Weekly Recap Notes")
        ]

        let interimExpectation = XCTestExpectation(description: "received interim")
        let finalExpectation = XCTestExpectation(description: "received final")

        coordinator.$stateByMemo
            .dropFirst()
            .sink { state in
                if case .streaming(let text) = state[memo.id] {
                    if text == "Weekly" {
                        interimExpectation.fulfill()
                    }
                }
                if case .success(let title) = state[memo.id], title == "Weekly Recap Notes" {
                    finalExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        coordinator.enqueue(memoId: memo.id)

        await fulfillment(of: [interimExpectation, finalExpectation], timeout: 2.0)
    }

    // MARK: - Helpers

    private func makeTestMemo() throws -> Memo {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        try Data([0x00, 0x01, 0x02]).write(to: tempURL)

        let memo = Memo(
            filename: tempURL.lastPathComponent,
            fileURL: tempURL,
            creationDate: Date()
        )

        memoRepository.saveMemo(memo)
        memoRepository.loadMemos()
        return memoRepository.getMemo(by: memo.id) ?? memo
    }
}

private final class MockTitleService: TitleServiceProtocol {
    enum Result {
        case success(String?)
        case stream(partials: [String], final: String)
        case failure(Error)
    }

    var results: [Result] = []

    func generateTitle(
        transcript: String,
        languageHint: String?,
        progress: TitleStreamingHandler?
    ) async throws -> String? {
        guard !results.isEmpty else { return nil }
        switch results.removeFirst() {
        case .success(let value):
            return value
        case .stream(let partials, let final):
            partials.forEach { partial in
                progress?(TitleStreamingUpdate(text: partial, isFinal: false))
            }
            progress?(TitleStreamingUpdate(text: final, isFinal: true))
            return final
        case .failure(let error):
            throw error
        }
    }
}
