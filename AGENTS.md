# AGENTS.md — Agent Contribution Guide for Sonora

This guide aligns autonomous coding agents with Sonora's **exemplary Clean Architecture** and **native SwiftUI implementation**. It summarizes how to plan, implement, and document changes safely while maintaining the project's **95% architectural compliance** and **clean, standard Apple UI**.

## Mission

- **Preserve Architectural Excellence**: Maintain 95% Clean Architecture compliance
- **Maintain Native SwiftUI**: Honor clean, standard Apple UI components and patterns
- **Single Source of Truth**: Use unified `Memo` model across all layers
- **Protocol-First Development**: Continue exemplary dependency injection patterns
- **Accessibility & Performance**: Maintain standard accessibility patterns with system integration

## Architectural Ground Rules

- **Layers**: Presentation (SwiftUI + ViewModels), Domain (Use Cases, Models, Protocols), Data (Repositories, Services), Core (DI, Concurrency, Events, Logging, Config)
- **Memo Model**: Use unified `Memo` everywhere (no adapters). Transport/persistence forms: suffix them (`MemoDTO`, `MemoRecord`)
- **Repository Scope**: Data access only; orchestration belongs to Use Cases or Event Handlers
- **Domain Purity**: Keep AVFoundation/UI frameworks outside Domain layer (pure Swift only)

## UI Development Guidelines

- **Native SwiftUI Components**: Use standard SwiftUI elements (`.borderedProminent`, `.bordered`, `List`, etc.)
- **System Integration**: Follow iOS design guidelines and use system colors/fonts
- **Theme Management**: Respect `ThemeManager` for light/dark mode and accessibility settings  
- **Performance**: Standard SwiftUI components are optimized by Apple - maintain native behavior
- **Accessibility**: Use standard accessibility patterns and VoiceOver support

## Dependency Injection

- Composition root: `Core/DI/DIContainer.swift`.
- Prefer constructor injection with protocols (e.g., `MemoRepository`, `TranscriptionAPI`).
- Avoid new singletons. If a global is necessary, add a protocol and inject it via the container.

## Operations & Events

- Register long-running work (recording, transcription, analysis) with `OperationCoordinator`.
- Use delegate/status APIs for progress or queue position.
- Publish `AppEvent` for cross-cutting reactions (e.g., `memoCreated`, `transcriptionCompleted`). Handlers in `Core/Events` should react, not ViewModels.

## Error Handling & Logging

- Map system errors via `ErrorMapping` → `SonoraError`.
- Use `Logger` with `LogContext` for structured logs and correlation IDs in Use Cases.
- Don’t throw raw `NSError` out of a Use Case without mapping.

## Naming & Structure

- Entities: `Memo`, `DomainAnalysisResult`.
- Transport/persistence: `*DTO`, `*Record`/`*Entity` as needed.
- View state types only when warranted (e.g., `MemoViewState`), otherwise keep state in ViewModels.
- Swift style: clear names, no one-letter locals, respect file-local meaning.

## Adding a Feature (Happy Path)

1) Domain
- Define/extend a protocol if needed.
- Add a `UseCase` with a protocol (single responsibility, pure logic). Inject protocols.

2) Data
- Implement or extend a repository/service behind a protocol. Keep logic thin.

3) Presentation
- Inject the Use Case(s) into a ViewModel. Expose minimal state for the View.
- Keep UI updates on `@MainActor`.

4) Cross-cutting
- Register operations with `OperationCoordinator` if long-running.
- Publish `AppEvent` for cross-feature behavior where applicable.

5) Documentation
- Update README.md/ARCHITECTURE.md if you change behavior, boundaries, or public APIs.

## Do / Don’t Checklist

- Do: constructor-inject protocols; keep ViewModels thin; write small, focused Use Cases.
- Do: surface Combine publishers from repos/services instead of polling.
- Do: log meaningful context; map errors to domain errors.
- Don’t: introduce a second memo model; rely on adapters; leak UI/AV into Domain.
- Don’t: add new singletons; do not resolve the container deep inside business code.

## Patch Discipline (for agents)

- Use minimal diffs; keep changes scoped to the task; don’t opportunistically refactor unrelated code.
- Mirror existing code style and file layout.
- When renaming core types, update imports/usages and docs in one pass.

## Testing Notes

### Architecture Testing
- See `docs/testing/` for complete flows: background recording, enhanced recording, and transcription integration
- **Use Case Testing**: Focus on business logic with mock repositories/services
- **ViewModel Testing**: Test state management and coordination logic
- **Repository Testing**: Verify data access and persistence patterns

### UI Testing with XcodeBuildMCP
- **Always use `describe_ui` before `tap`** - Never guess coordinates from screenshots
- **Standard UI Elements**: UI uses native SwiftUI components with standard touch targets
- **Recording Flow**: Test background recording with Live Activities integration
- **Theme Changes**: Test light/dark mode transitions with system colors

#### Common Testing Commands
```bash
# Build and run simulator
build_run_sim({ projectPath: '/path/to/Sonora.xcodeproj', scheme: 'Sonora', simulatorName: 'iPhone 16' })

# UI interaction pattern
describe_ui({ simulatorUuid: "UUID" })  # Get precise coordinates
tap({ simulatorUuid: "UUID", x: 187, y: 256 })  # Use exact coordinates
```

## Quick References

- Composition root: `Core/DI/DIContainer.swift`
- Operations: `Core/Concurrency/*`
- Events: `Core/Events/*`
- Domain Use Cases: `Domain/UseCases/*`
- Repositories: `Data/Repositories/*`
- Services: `Data/Services/*`
- ViewModels: `Presentation/ViewModels/*`

