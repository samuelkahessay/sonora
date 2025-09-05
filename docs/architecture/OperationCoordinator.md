# OperationCoordinator

Context
- Sonora runs long‑lived, cancellable operations that must not conflict: Recording, Transcription, and Analysis. The app needs a centralized way to avoid invalid combinations (e.g. transcribing a memo while it is still recording), report a user‑visible queue, provide progress and global system status, and support cancellation.

Decision
- We use a custom, actor‑backed `OperationCoordinator` singleton to coordinate these operations. An off‑the‑shelf queue would not understand Sonora’s domain conflicts (per‑memo, per‑category) nor expose the UX we want (queue order, metrics, progress events). The actor model gives predictable, race‑free state without locks.

Core Concepts
- Actor isolation: All state (operations, active‑by‑memo index, pending queue) is confined to the coordinator actor.
- Operation model: `OperationType` (recording, transcription, analysis), `OperationStatus` (pending/active/completed/failed/cancelled), `OperationPriority` (high/medium/low), and conflict rules per `OperationCategory`.
- Registration → Start → Progress → Finish: Callers request an operation (`registerOperation`). The coordinator checks capacity and conflicts. If allowed, it inserts and tries to start. Once active, clients may report progress. Finishing transitions to a terminal state, notifies UI via a weak @MainActor delegate and coarse `AppEvent`s, then attempts to start queued operations and performs cleanup.
- Queueing: A simple priority queue (high first, then FIFO by creation). Capacity is enforced at registration time to keep `start()` cheap.
- UI integration: Two channels coexist by design: (1) a weak `OperationStatusDelegate` (fine‑grained status for specific screens), (2) EventBus `AppEvent`s (coarse app‑wide events used by multiple surfaces including Live Activities).

Known Limitations & Risks
- Centralized singleton increases cognitive load and coupling.
- Capacity is enforced only during registration; bursts may lead to momentary oversubscription if external work is slow to complete.
- Analysis operations generally do not conflict; coordinating all of them can inflate metrics and add complexity without UX benefit.
- The weak delegate can change while callbacks are in flight; we tolerate this because updates are best‑effort notifications.

Recent Refinements (De‑Risking)
- Cache‑hit fast path: Distill analysis use cases now skip `OperationCoordinator` entirely when a cached result exists. This reduces churn, metrics noise, and complexity for the simplest path.
- Documentation: The coordinator file documents purpose, invariants, state transitions, and concurrency notes. Areas with trade‑offs or potential races are explicitly called out.

- Simple analysis use cases decoupled: Themes, Todos, and Content analyses no longer register operations with the coordinator. They run via standard Swift `Task.detached`, persist results in the repository, and publish completion through `EventBus`. This further solidifies the coordinator’s scope around heavy, stateful operations (Recording, Transcription, Distill flows).

Future Work
- Gradually migrate simple analysis operations (those without progress/queueing UX) to plain `Task`s that publish completion via `EventBus`.
- Add per‑category concurrency caps (e.g., at most N analyses) if user experience benefits from explicit pacing.
- Consider replacing the weak delegate with scoped subscription tokens or dedicated `EventBus` channels for unified delivery semantics.
- Expose read‑only snapshots for metrics that are composable in SwiftUI previews/tests.
