Here’s a concise review with concrete adjustments based on what’s in the repo.

  Overall

  - Solid plan and right priorities. A few assumptions don’t match current code; I’ve corrected them and suggested tighter, file-specific changes for Phase 1.

  What Aligns

  - Adaptive thresholds, near-miss logging, temporal refinement already implemented (Sonora/Domain/UseCases/EventKit/DetectEventsAndRemindersUseCase.swift:240).
  - UI is modular and already moved EventKit operations out of state into a coordinator (Sonora/Features/Analysis/Coordinators/ActionItemCoordinator.swift:1).
  - Server validates AI responses with Zod + JSON Schema (server/src/schema.ts:1, server/src/schema.ts:240).
  - UI-level dedup across events vs reminders exists (Sonora/Features/Analysis/UI/Components/DistillDetectionsUtils.swift:32).

  Gaps/Corrections

  - Permission “200ms sleep”: I see blocking retries during save, not permission stabilization (Thread.sleep in EventKit repository). Replace these, but do it without blocking the main
  actor (Sonora/Data/Repositories/EventKitRepositoryImpl.swift:246, Sonora/Data/Repositories/EventKitRepositoryImpl.swift:331).
  - “Monolithic” state: ActionItemDetectionState is large but event/reminder creation is already factored into ActionItemCoordinator. A light consolidation into a single ViewModel is
  still useful, but not an urgent fix (Sonora/Features/Analysis/UI/Components/ActionItemDetectionState.swift:1).
  - “Direct repo access from state”: No longer true; coordinator handles EventKit via DI (Sonora/Features/Analysis/Coordinators/ActionItemCoordinator.swift:1).
  - “No dedup for event vs reminder overlap”: UI-level dedup exists; moving this to the domain layer would be a better long-term place (Sonora/Features/Analysis/UI/Components/
  DistillDetectionsUtils.swift:32).
  - Shared EKEventStore: You do share a single repository instance, but EKEventStore instances for repository and permission service are separate. Inject one shared store into both for
  best perf (Sonora/Core/DI/DIContainer.swift:521, Sonora/Data/Services/EventKit/EventKitPermissionService.swift:1).

  Phase 1 Refinements (Week 1)

  - Replace blocking retries:
      - Swap Thread.sleep with try await Task.sleep and make the save helpers async to avoid blocking main actor during retries (Sonora/Data/Repositories/EventKitRepositoryImpl.swift:246,
  Sonora/Data/Repositories/EventKitRepositoryImpl.swift:331). Then propagate async up to call sites.
  - Add permission stabilization as a utility:
      - Add await stabilizeAuthorization(for: .event/.reminder, timeout: 1.0) that polls EKEventStore.authorizationStatus every 100ms (max 1s) inside EventKitPermissionService and call it
  after requests (Sonora/Data/Services/EventKit/EventKitPermissionService.swift:1).
  - Tighten prompts to remove ambiguity:
      - In events mode, replace “unless the phrase suggests otherwise” with explicit slots: morning=09:00, afternoon=14:00, evening=18:00; avoid subjective language (server/src/
  prompts.ts:1).
      - Align reminder defaults to same slots for consistency; you already have explicit examples—just make them authoritative language (server/src/prompts.ts:1).
  - Add a minimal DetectionValidator:
      - New domain utility to validate decoded data: unique IDs, confidence in [0,1], event end ≥ start, clamp absurd titles/participants, drop malformed items before thresholding.
  Integrate just after decode and before thresholding (new: Sonora/Domain/Services/Detection/DetectionValidator.swift).
  - Domain-level deduplication:
      - Move overlap dedup (currently in UI) to domain so downstream layers receive clean sets, then let UI render. Extract/port logic from dedupeDetections into a new pure
  service (new: Sonora/Domain/Services/Detection/DeduplicationService.swift). Update DetectEventsAndRemindersUseCase to call it post-refinement (Sonora/Domain/UseCases/EventKit/
  DetectEventsAndRemindersUseCase.swift:240).

  Phases 2–4 Notes

  - Phase 2 (ViewModel consolidation):
      - Create ActionItemViewModel that composes ActionItemDetectionState + ActionItemCoordinator to centralize unidirectional flow. This is a thin layer change, since coordinator/state
  already separate responsibilities (new: Sonora/Features/Analysis/ViewModels/ActionItemViewModel.swift).
  - Phase 3 (EventKit robustness):
      - Inject a single shared EKEventStore into both permission service and repository via DI (Sonora/Core/DI/DIContainer.swift:521).
      - Add duplicate detection before save: search for identical title within ±15 minutes for same day, or identical sourceText hash; expose findDuplicates(similarTo:) and call it in
  coordinator before creation. Optionally surface a simple conflict sheet (new: Sonora/Features/Analysis/UI/Components/EventConflictResolutionSheet.swift).
      - Recurring: extend EventsData.DetectedEvent with an optional recurrence payload and translate to EKRecurrenceRule. You’ll need matching schema + prompt updates on the server.
  - Phase 4 (Testing + calibration):
      - Confidence calibration can piggyback off handled/accepted items from DistillHandledDetectionsStore, feeding a small adaptive offset in AdaptiveThresholdPolicy. Ship behind a
  feature flag first.

  Priority Tests (add these first)

  - Detect use case thresholds and fallback:
      - When no items pass threshold, ensure top-k fallback behavior is applied correctly (Sonora/Domain/UseCases/EventKit/DetectEventsAndRemindersUseCase.swift:240).
  - TemporalRefiner edge cases:
      - Already present; extend for “tonight/this weekend/next week” with part-of-day overrides (Sonora/Domain/Services/Temporal/TemporalRefiner.swift:27).
  - Dedup service unit tests:
      - Event vs reminder overlap and idempotency of the deduper (new: SonoraTests/Detection/DeduplicationServiceTests.swift).
  - Permission service mapping + stabilization:
      - Map EK statuses correctly; simulate request completion + stabilization window (Sonora/Data/Services/EventKit/EventKitPermissionService.swift:1).
  - Coordinator payload composition:
      - Verify buildEventPayload/buildReminderPayload preserve duration, sourceText, and memoId correctly (Sonora/Features/Analysis/UI/Components/DistillDetectionsUtils.swift:90).

  Quick Wins This Week

  - Replace Thread.sleep with async sleeps to avoid main-thread blocking (Sonora/Data/Repositories/EventKitRepositoryImpl.swift:246).
  - Tighten events prompt defaults; remove subjective clause (server/src/prompts.ts:1).
  - Add domain DetectionValidator and call it before threshold filtering (new: Sonora/Domain/Services/Detection/DetectionValidator.swift).
  - Add 3–5 tests listed above under SonoraTests.

  If you want, I can implement Phase 1 now and run unit tests on iPhone 16 Pro simulator.