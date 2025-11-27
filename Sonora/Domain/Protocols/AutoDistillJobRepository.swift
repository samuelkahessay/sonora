import Combine
import Foundation

/// Protocol for managing Auto Distillation jobs
/// Must be @MainActor since implementations interact with SwiftData ModelContext
@MainActor
protocol AutoDistillJobRepository {
    var jobsPublisher: AnyPublisher<[AutoDistillJob], Never> { get }

    func fetchAllJobs() -> [AutoDistillJob]
    func fetchQueuedJobs() -> [AutoDistillJob]
    func job(for memoId: UUID) -> AutoDistillJob?
    func save(_ job: AutoDistillJob)
    func deleteJob(for memoId: UUID)
}
