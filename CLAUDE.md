# Sonora — Developer Guide (Concise)

This repo uses Clean Architecture with SwiftUI. Keep domain code pure, inject dependencies via protocols, and prefer native iOS components.

## Project layout
- `Core/` – DI, logging, concurrency, utilities
- `Domain/` – models, use cases, repository protocols (pure Swift)
- `Data/` – repositories + services (Apple/OS/network integration)
- `Presentation/` – SwiftUI views and ViewModels
- `Models/` – cross‑layer shared types
- `SonoraTests/`, `SonoraUITests/` – tests

## Build and run (CLI)
- List simulators: `list_sims()`
- Build: `build_sim({ projectPath: 'Sonora.xcodeproj', scheme: 'Sonora', simulatorId: '<UUID>' })`
  - Use installed sims only: iPhone 16 Pro (iOS 18.6), iPhone 17 Pro (iOS 26)
  - Prefer `simulatorId`; if using names, set `useLatestOS: false`
- Xcode fallback:
  - Build: `xcodebuild build -project Sonora.xcodeproj -scheme Sonora -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
  - Unit tests: `xcodebuild test -scheme SonoraTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
  - UI tests: `xcodebuild test -scheme SonoraUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`

## Add a feature
1) Domain: add a use case (single responsibility).
2) Data: create/extend a repository or service behind a protocol.
3) Presentation: inject the use case into a `@MainActor` ViewModel; call it from the view.

Guidelines
- Constructor‑inject protocols; do not access `DIContainer` inside domain/data.
- Keep domain types framework‑free (no UIKit/AVFoundation).
- Prefer `struct` unless reference semantics are required.
- Use semantic colors and system components; avoid custom chrome unless necessary.

## Concurrency (Swift 6‑ready)
- ViewModels and UI: `@MainActor`.
- Use cases: actor‑agnostic; run work off the main thread.
- Repositories that touch Apple frameworks (e.g., EventKit): `@MainActor`; hop to background internally if needed.
- UI updates from background: `await MainActor.run { … }`.
- Avoid `@unchecked Sendable` unless justified.

## Dependency injection
- Composition root: `Core/DI/DIContainer.swift`.
- Access dependencies at app edges, pass them down. Example:
  ```swift
  @MainActor final class MyVM: ObservableObject {
      private let useCase: MyUseCaseProtocol
      init(useCase: MyUseCaseProtocol = DIContainer.shared.myUseCase()) { self.useCase = useCase }
  }
  ```

## Testing
- Place unit tests in `SonoraTests/`; use async/await.
- Name tests `TypeNameTests` and methods `test_condition_expectedResult`.
- Keep mocks in `SonoraTests/MockServices.swift`.

## UI conventions
- SwiftUI first; List/TabView/Form over custom stacks.
- `@MainActor` ViewModels with small, immutable `State` structs.
- Avoid global singletons in views; use environment/DI.

## Common tasks
- Show onboarding again (debug): Settings → About & Support → Diagnostics → Debug Tools → “Show Onboarding Again”.
- Change display name: Settings → Personalization → Display Name.

## Review checklist
- Single‑purpose use case? Pure domain logic?
- Protocol‑backed repositories/services? No DIContainer in domain/data?
- ViewModel `@MainActor`? No UI work off the main thread?
- Tests updated for new business logic?
- Uses system components/colors and respects light/dark mode?

That’s it. Build, inject via protocols, keep domain pure, and prefer native UI.
- ALWAYS use XCodeBuild MCP to test builds