# ARCHIVE — Historical Notes (Resolved)

This archive summarizes previously separate historical documents that are now consolidated here for brevity. All items below are resolved and kept for reference only.

## 1) Synchronous Recording Interface (Resolved)
- Goal: Preserve synchronous `execute()` interfaces for recording use cases while enabling background recording.
- Outcome:
  - Use cases remain synchronous (`StartRecordingUseCase.execute()`, `StopRecordingUseCase.execute()`)
  - `AudioRepositoryImpl` handles background behavior internally
  - Recording remains stable with a global 60s limit and 10s countdown
- Notes: Legacy adapter examples were removed; the app uses repository-backed flows.

## 2) Build Errors Fixed — Recording Use Cases (Resolved)
- Issues addressed:
  - Duplicate/legacy wrapper references during migration
  - Async/await mismatches and MainActor access warnings in tests
- Outcome:
  - Consolidated to repository-backed recording
  - Fixed main-actor usage in testing utilities
  - All prior build errors resolved

## 3) Transcription Use Cases — Main Actor Isolation (Resolved)
- Problem: Convenience initializers accessed DI from non-isolated contexts, triggering MainActor isolation errors.
- Approach:
  - Introduced factory methods marked `@MainActor` for safe composition
  - Preferred construction uses repository-backed flows for persistence
- Outcome:
  - Zero actor-isolation build errors
  - Backward compatibility retained during migration; legacy paths subsequently removed

---

For current architecture, testing, and development guidance, see:
- README.md (current architecture, metrics, and defaults)
- ARCHITECTURE_MIGRATION.md (status and next steps)
- docs/testing (active testing guides)

