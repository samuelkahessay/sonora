import XCTest
import SwiftData
@testable import Sonora

final class SwiftDataRepositoriesTests: XCTestCase {
    var container: ModelContainer! = nil
    var context: ModelContext! = nil

    override func setUpWithError() throws {
        let schema = Schema([
            MemoModel.self,
            TranscriptionModel.self,
            AnalysisResultModel.self,
            AutoTitleJobModel.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Mocks
    @MainActor
    private struct MockStartTranscription: StartTranscriptionUseCaseProtocol {
        func execute(memo: Memo) async throws {}
    }
    @MainActor
    private struct MockGetTranscriptionState: GetTranscriptionStateUseCaseProtocol {
        private let repo: any TranscriptionRepository
        init(repo: any TranscriptionRepository) { self.repo = repo }
        func execute(memoId: UUID) -> TranscriptionState { repo.getTranscriptionState(for: memoId) }
    }
    @MainActor
    private struct MockRetryTranscription: RetryTranscriptionUseCaseProtocol {
        func execute(memoId: UUID) async throws {}
    }

    private func makeAudioTempFile(name: String = UUID().uuidString) throws -> URL {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let url = tmp.appendingPathComponent(name).appendingPathExtension("m4a")
        try Data([0x00, 0x01, 0x02]).write(to: url)
        return url
    }

    @MainActor
    func testMemoCRUDAndSorting() throws {
        let trRepo = TranscriptionRepositoryImpl(context: context)
        let jobRepo = AutoTitleJobRepositoryImpl(context: context)
        let memoRepo = MemoRepositoryImpl(
            context: context,
            transcriptionRepository: trRepo,
            autoTitleJobRepository: jobRepo
        )

        let audio1 = try makeAudioTempFile(name: "a1")
        let audio2 = try makeAudioTempFile(name: "a2")

        let older = Date().addingTimeInterval(-3600)
        let m1 = Memo(id: UUID(), filename: "m1.m4a", fileURL: audio1, creationDate: older)
        let m2 = Memo(id: UUID(), filename: "m2.m4a", fileURL: audio2, creationDate: Date())

        memoRepo.saveMemo(m1)
        memoRepo.saveMemo(m2)
        memoRepo.loadMemos()

        XCTAssertEqual(memoRepo.memos.count, 2)
        XCTAssertEqual(memoRepo.memos.first?.id, m2.id, "Newest memo should be first")

        // Rename
        memoRepo.renameMemo(m2, newTitle: "Meeting Notes")
        let fetched = memoRepo.getMemo(by: m2.id)
        XCTAssertEqual(fetched?.customTitle, "Meeting Notes")
    }

    @MainActor
    func testDeleteCascadeRemovesTranscriptionAndAnalysis() async throws {
        let trRepo = TranscriptionRepositoryImpl(context: context)
        let anRepo = AnalysisRepositoryImpl(context: context)
        let jobRepo = AutoTitleJobRepositoryImpl(context: context)
        let memoRepo = MemoRepositoryImpl(
            context: context,
            transcriptionRepository: trRepo,
            autoTitleJobRepository: jobRepo
        )

        let audio = try makeAudioTempFile(name: "b1")
        let memo = Memo(id: UUID(), filename: "b1.m4a", fileURL: audio, creationDate: Date())
        memoRepo.saveMemo(memo)

        // Persist linked transcription/analysis
        trRepo.saveTranscriptionState(.completed("hello world"), for: memo.id)

        struct Dummy: Codable { let value: String }
        let env = AnalyzeEnvelope(mode: .analysis, data: Dummy(value: "ok"), model: "test", tokens: TokenUsage(input: 1, output: 1), latency_ms: 1, moderation: nil)
        anRepo.saveAnalysisResult(env, for: memo.id, mode: .analysis)

        // Delete memo and verify cascades in store
        memoRepo.deleteMemo(memo)

        let tFetch = try context.fetch(FetchDescriptor<TranscriptionModel>(predicate: #Predicate { $0.memo?.id == memo.id }))
        let aFetch = try context.fetch(FetchDescriptor<AnalysisResultModel>(predicate: #Predicate { $0.memo?.id == memo.id }))
        XCTAssertTrue(tFetch.isEmpty, "Transcription should be deleted by cascade")
        XCTAssertTrue(aFetch.isEmpty, "Analysis results should be deleted by cascade")
    }

    @MainActor
    func testAnalysisLatestResultFetch() throws {
        let trRepo = TranscriptionRepositoryImpl(context: context)
        let anRepo = AnalysisRepositoryImpl(context: context)
        let jobRepo = AutoTitleJobRepositoryImpl(context: context)
        let memoRepo = MemoRepositoryImpl(
            context: context,
            transcriptionRepository: trRepo,
            autoTitleJobRepository: jobRepo
        )

        let audio = try makeAudioTempFile(name: "c1")
        let memo = Memo(id: UUID(), filename: "c1.m4a", fileURL: audio, creationDate: Date())
        memoRepo.saveMemo(memo)

        struct Dummy: Codable { let n: Int }
        let first = AnalyzeEnvelope(mode: .analysis, data: Dummy(n: 1), model: "m", tokens: TokenUsage(input: 1, output: 1), latency_ms: 1, moderation: nil)
        let second = AnalyzeEnvelope(mode: .analysis, data: Dummy(n: 2), model: "m", tokens: TokenUsage(input: 2, output: 2), latency_ms: 2, moderation: nil)
        anRepo.saveAnalysisResult(first, for: memo.id, mode: .analysis)
        anRepo.saveAnalysisResult(second, for: memo.id, mode: .analysis)

        let latest: AnalyzeEnvelope<Dummy>? = anRepo.getAnalysisResult(for: memo.id, mode: .analysis, responseType: Dummy.self)
        XCTAssertEqual(latest?.data.n, 2, "Should fetch latest by timestamp")
    }

    @MainActor
    func testAutoTitleJobFailurePersistence() throws {
        let trRepo = TranscriptionRepositoryImpl(context: context)
        let jobRepo = AutoTitleJobRepositoryImpl(context: context)
        let memoRepo = MemoRepositoryImpl(
            context: context,
            transcriptionRepository: trRepo,
            autoTitleJobRepository: jobRepo
        )

        let audio = try makeAudioTempFile(name: "failure")
        let memo = Memo(id: UUID(), filename: "failure.m4a", fileURL: audio, creationDate: Date())
        memoRepo.saveMemo(memo)

        let job = AutoTitleJob(
            memoId: memo.id,
            status: .failed,
            createdAt: Date().addingTimeInterval(-120),
            updatedAt: Date(),
            retryCount: 2,
            lastError: "Network unreachable",
            nextRetryAt: nil,
            failureReason: .network
        )
        jobRepo.save(job)

        let fetchedJob = jobRepo.job(for: memo.id)
        XCTAssertEqual(fetchedJob?.failureReason, .network)
        XCTAssertEqual(fetchedJob?.lastError, "Network unreachable")

        memoRepo.loadMemos()
        let storedMemo = memoRepo.getMemo(by: memo.id)
        guard case .failed(let reason, let message) = storedMemo?.autoTitleState else {
            return XCTFail("Expected memo autoTitleState to reflect failure")
        }
        XCTAssertEqual(reason, .network)
        XCTAssertEqual(message, "Network unreachable")
    }
}
