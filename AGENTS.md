# AGENTS.md — Agent Contribution Guide for Sonora

This guide aligns autonomous coding agents with Sonora’s architecture and conventions. It summarizes how to plan, implement, and document changes safely in this repository.

## Mission

- Keep the app aligned with Clean Architecture + MVVM.
- Maintain a single memo model named `Memo` across layers.
- Prefer protocol-first composition and constructor injection.
- Preserve separation of concerns and thin ViewModels.

## Architectural Ground Rules

- Layers: Presentation (SwiftUI + ViewModels), Domain (Use Cases, Models, Protocols), Data (Repositories, Services), Core (DI, Concurrency, Events, Logging, Config).
- Memo model: Use `Memo` everywhere (no `DomainMemo`, no adapters). If you introduce transport/persistence forms, suffix them (`MemoDTO`, `MemoRecord`).
- Repositories are for data access; orchestration belongs to Use Cases or Event Handlers.
- Keep AVFoundation/UI frameworks outside the Domain layer. Domain stays pure Swift.

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

- See `docs/testing/` for flows: background recording, enhanced recording, and transcription integration.
- Prefer targeted tests near changed code. For UI, keep logic in VMs and test their behaviors.

## Quick References

- Composition root: `Core/DI/DIContainer.swift`
- Operations: `Core/Concurrency/*`
- Events: `Core/Events/*`
- Domain Use Cases: `Domain/UseCases/*`
- Repositories: `Data/Repositories/*`
- Services: `Data/Services/*`
- ViewModels: `Presentation/ViewModels/*`

