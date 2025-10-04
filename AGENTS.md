# Repository Guidelines

## Project Structure & Module Organization
Core app code lives under `Sonora/`, split by Clean Architecture layers: `Core/` (DI, concurrency, logging), `Domain/` (models, use cases, protocols), and `Data/` (repositories, services). UI is organized under `Features/` (SwiftUI feature modules) and shared UI under `Views/` where applicable. Shared models that bridge layers reside in `Models/`. Unit tests are in `SonoraTests/`, UI automation sources are in `SonoraUITests/` (no separate shared scheme yet), and the Live Activity target sits in `SonoraLiveActivity/` (with shared attributes in `Sonora/LiveActivity/`). Treat subdirectories as the single source of truth; do not duplicate models across layers.

## Build, Test, and Development Commands
Use Xcode 16+ or these CLI shortcuts:
- `xcodebuild build -project Sonora.xcodeproj -scheme Sonora -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` – compile the main app for a simulator.
- `xcodebuild test -project Sonora.xcodeproj -scheme Sonora -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` – run the unit test suite (tests are included in the `Sonora` scheme).
- UI tests: there is no separate shared `SonoraUITests` scheme at the moment. Run from Xcode by adding the `SonoraUITests` target to the `Sonora` scheme’s Test action, or create/share a dedicated scheme if needed.
When adding Swift packages, run `xcodebuild -resolvePackageDependencies` to refresh the cache.

Within Codex CLI, prefer using the XcodeBuildMCP tools to build the app instead of raw `xcodebuild`.

MCP-first policy (builds and test builds):
- Use XcodeBuild MCP for all builds and test builds first; only fall back to `xcodebuild` if MCP is unavailable or blocked.
- To compile tests without running them, pass `extraArgs: ['build-for-testing']` to MCP build calls.

Examples (test build via MCP):
- `build_sim({ projectPath: 'Sonora.xcodeproj', scheme: 'Sonora', simulatorId: '<UUID from list_sims>', extraArgs: ['build-for-testing'] })`

- Use installed simulators only: `iPhone 16 Pro (iOS 18.6)` and `iPhone 17 Pro (iOS 26)`.
- Prefer targeting a specific existing simulator by UUID to avoid downloads/creation: first call `list_sims()`, then pass `simulatorId` to MCP commands.
- If you use `simulatorName`, specify the exact name and set `useLatestOS: false` to prevent triggering an OS download.

Examples (Codex MCP pseudo-calls):
- `build_run_sim({ projectPath: 'Sonora.xcodeproj', scheme: 'Sonora', simulatorId: '<UUID from list_sims>' })`
- `build_run_sim({ projectPath: 'Sonora.xcodeproj', scheme: 'Sonora', simulatorName: 'iPhone 16 Pro', useLatestOS: false })`
- `build_sim({ projectPath: 'Sonora.xcodeproj', scheme: 'Sonora', simulatorName: 'iPhone 17 Pro', useLatestOS: false })`

Avoid passing generic or unavailable models (e.g., `iPhone 16`) that could cause MCP to create/download a new device. Always target the existing `iPhone 16 Pro` or `iPhone 17 Pro` or use their UUIDs.

## Coding Style & Naming Conventions
Write Swift using the standard four-space indentation, trailing commas where Xcode applies them, and `camelCase` identifiers. Follow the existing Clean Architecture guidelines: inject protocols via initialisers, keep domain types pure Swift (no UIKit/AVFoundation), and suffix transport structs with `DTO` or `Record`. Prefer `struct` over `class` unless reference semantics are required, and use `@MainActor` on ViewModels and UI-bound use cases.

## Testing Guidelines
Unit tests rely on XCTest with async/await helpers. Name test files after the type under test (`StartTranscriptionUseCaseTests`). Individual tests should read `test_condition_expectedResult`. Keep mocks colocated with the tests that use them (e.g., inline `Mock*` types in the test file or a small helper in the nearest test subfolder) rather than a central `MockServices.swift`. Run unit tests via the `Sonora` scheme before opening a PR; UI test runs are encouraged for visual or interaction changes (run from Xcode unless a shared scheme is added). Aim to extend coverage whenever you add a new use case or repository method.

## Commit & Pull Request Guidelines
Commit messages should be concise, present-tense summaries (e.g., `Add filler-word filter for transcripts`). Group related changes; avoid sweeping refactors with feature work. Pull requests must describe the change, reference tickets, and call out testing steps (`xcodebuild test …`). Include screenshots or recordings when UI surfaces change. Ensure CI passes and request review from a teammate responsible for the affected layer (Data, Domain, Presentation, or Core).
