import Foundation
import Combine

@MainActor
final class TitleGenerationTracker: ObservableObject, TitleGenerationTracking, @unchecked Sendable {
    @Published private(set) var stateByMemo: [UUID: TitleGenerationState] = [:]

    func setInProgress(_ memoId: UUID) {
        print("🧠 TitleTracker: inProgress for memo=\(memoId)")
        stateByMemo[memoId] = .inProgress
        objectWillChange.send()
    }

    func setSuccess(_ memoId: UUID, title: String) {
        print("🧠 TitleTracker: success for memo=\(memoId) title=\(title)")
        stateByMemo[memoId] = .success(title)
        objectWillChange.send()
        // Optionally clear after a short delay to avoid lingering state
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self else { return }
            if case .success = self.stateByMemo[memoId] {
                print("🧠 TitleTracker: auto-clear success -> idle for memo=\(memoId)")
                self.stateByMemo[memoId] = .idle
                self.objectWillChange.send()
            }
        }
    }

    func setFailed(_ memoId: UUID) {
        print("🧠 TitleTracker: failed for memo=\(memoId)")
        stateByMemo[memoId] = .failed
        objectWillChange.send()
        // Clear failure marker after a bit; no persistent UI needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self else { return }
            if case .failed = self.stateByMemo[memoId] {
                print("🧠 TitleTracker: auto-clear failed -> idle for memo=\(memoId)")
                self.stateByMemo[memoId] = .idle
                self.objectWillChange.send()
            }
        }
    }

    func state(for memoId: UUID) -> TitleGenerationState {
        stateByMemo[memoId] ?? .idle
    }
}
