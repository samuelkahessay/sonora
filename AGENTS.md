# Repository Guidelines

## Project Structure & Module Organization
Core app code lives under `Sonora/`, split by Clean Architecture layers: `Core/` (DI, concurrency, logging), `Domain/` (models, use cases, protocols), `Data/` (repositories, services), and `Presentation/` (SwiftUI features). Shared models that bridge layers reside in `Models/`. Unit tests are in `SonoraTests/`, UI automation in `SonoraUITests/`, and the Live Activity target sits in `SonoraLiveActivity/`. Treat subdirectories as the single source of truth; do not duplicate models across layers.

## Build, Test, and Development Commands
Use Xcode 16+ or these CLI shortcuts:
- `xcodebuild build -project Sonora.xcodeproj -scheme Sonora -destination 'platform=iOS Simulator,name=iPhone 16'` – compile the main app for a simulator.
- `xcodebuild test -scheme SonoraTests -destination 'platform=iOS Simulator,name=iPhone 16'` – run the unit test suite.
- `xcodebuild test -scheme SonoraUITests -destination 'platform=iOS Simulator,name=iPhone 16'` – execute UI tests (ensure the simulator is booted).
When adding Swift packages, run `xcodebuild -resolvePackageDependencies` to refresh the cache.

Within Codex CLI, prefer using the XcodeBuildMCP tools to build the app instead of raw `xcodebuild`.

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
Unit tests rely on XCTest with async/await helpers. Name test files after the type under test (`StartTranscriptionUseCaseTests`). Individual tests should read `test_condition_expectedResult`. Keep mocks in `SonoraTests/MockServices.swift`. Run SonoraTests before opening a PR; UI test runs are encouraged for visual or interaction changes. Aim to extend coverage whenever you add a new use case or repository method.

## Commit & Pull Request Guidelines
Commit messages should be concise, present-tense summaries (e.g., `Add filler-word filter for transcripts`). Group related changes; avoid sweeping refactors with feature work. Pull requests must describe the change, reference tickets, and call out testing steps (`xcodebuild test …`). Include screenshots or recordings when UI surfaces change. Ensure CI passes and request review from a teammate responsible for the affected layer (Data, Domain, Presentation, or Core).
