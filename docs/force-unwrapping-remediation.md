# Force-Unwrapping Remediation Plan

Goal: reduce force_unwrapping to 0 across app targets (Sonora, SonoraLiveActivity). Tests tracked separately.

Key patterns to apply
- Replace `!` with `guard let` or `if let` and early returns or throws.
- Convert impossible states into typed invariants via initializers/factories.
- Map failures to domain-specific errors (ServiceError, SonoraError, RepositoryError), not generic fatalErrors.
- In UI, prefer safe fallbacks with user feedback over crashing.

Hotspot checklist (from SwiftLint)

1) Core/DI/DIContainer.swift (22)
- Replace `shared!` and factory lookups with `guard let` + DIError.throw or preconditionFailure with context (only at init/bootstrap boundaries).
- Prefer constructor injection for ViewModels/UseCases over global resolves; pass defaults via factory.
- Outcome: no `!` in resolution paths; DI failure surfaces as developer error or typed error.

2) Core/Configuration/AppConfiguration.swift (6)
- `URL(string: ...)!` → guard + preconditionFailure with explicit message or inject via init.
- Unwrap env overrides safely; clamp/validate numeric bounds.
- Outcome: resilient config load; clear diagnostics without runtime crash.

3) Data/Repositories/MemoRepositoryImpl.swift (4)
- Model/context unwraps → guard with RepositoryError.
- File operations: guard path/URL validity; throw storage errors (RepositoryError.file*).

4) Features/Settings/ViewModels/AboutSupportLegalViewModel.swift (3)
- Safe URL building for support/privacy links; fallback to showing an alert if invalid.

5) Features/Settings/UI/PrivacyLegalSectionView.swift (2)
- Same as above; guard links before using `openURL`.

6) Domain/UseCases/EventKit/CreateReminderUseCase.swift (2)
7) Domain/UseCases/EventKit/CreateCalendarEventUseCase.swift (2)
8) Data/Repositories/EventKitRepositoryImpl.swift (2)
- EventKit entity unwraps → guard; map failures to domain/use-case errors (e.g., RepositoryError / ServiceError) instead of force unwrap.

9) Core/Errors/SonoraError.swift (1)
- Avoid force unwrap in string formatting; use optional chaining or nil-coalescing.

10) Data services
- VADSplittingService.swift (1), RecordingTimerService.swift (1), AudioRecordingService.swift (1)
- Guard file handles, buffers, and session state; throw ServiceError.* rather than unwrap.

11) Features/UI one-offs
- SupportAboutSectionView.swift (1), PromptViewModel.swift (1), ReminderConfirmationView.swift (1), EventConfirmationView.swift (1)
- Guard optionals from view models; surface alerts or disable actions if missing.

12) Live Activity
- SonoraLiveActivityLiveActivity.swift (1): guard widgetURL and intents; avoid `!`.

Execution plan (2–3 PRs)
- PR#1 (Core/Data safety): DIContainer, AppConfiguration, MemoRepositoryImpl, EventKit repo/use cases, Audio services.
  - Add DIError, refine init paths, and map unwraps to typed errors.
  - Run SonoraTests.
- PR#2 (UI safety + LiveActivity): Support/Privacy links, Prompt/Reminder/Event confirmation, LiveActivity URL.
  - Add minimal user feedback on invalid states.
- PR#3 (Tail cleanups): Remaining singles; add lint rule gate to keep zero regressions.

Verification
- Unit tests for DI failure paths, config loaders, and repos (invalid/edge cases).
- Smoke UI tests for settings links (ensure no crash on invalid URL).

CI gates
- Run `swiftlint lint --config .swiftlint.app.yml --baseline .swiftlint.baseline.yml` to ensure no new `force_unwrapping`.
- Analyzer pass on app for dead code/self capture.

Ownership
- Core: DI/Configuration/Errors → Core owner
- Data: Repositories/Services → Data owner
- Domain: EventKit UseCases → Domain owner
- UI & LiveActivity → Presentation owner

