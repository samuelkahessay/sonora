import Combine
import Foundation

@MainActor
protocol AutoTitleJobRepository: ObservableObject {
    var jobsPublisher: AnyPublisher<[AutoTitleJob], Never> { get }

    func fetchAllJobs() -> [AutoTitleJob]
    func fetchQueuedJobs() -> [AutoTitleJob]
    func job(for memoId: UUID) -> AutoTitleJob?
    func save(_ job: AutoTitleJob)
    func deleteJob(for memoId: UUID)
}
