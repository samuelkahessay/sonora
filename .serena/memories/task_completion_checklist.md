# Task Completion Checklist for Sonora

## Before Starting Any Task
- [ ] Run `git status && git branch` to check current state
- [ ] Activate project: `mcp__serena__activate_project({ project: "Sonora" })`
- [ ] Read relevant documentation from `docs/testing/` if testing-related

## Code Quality Requirements
- [ ] Follow Clean Architecture patterns (Use Cases → Repositories → Services)
- [ ] Use protocol-based dependency injection via DIContainer
- [ ] Ensure @MainActor isolation for UI components
- [ ] Use `any Protocol` syntax for Swift 6 compliance
- [ ] Add structured logging with LogContext for Use Cases

## When Writing Code
- [ ] Create Use Cases for business logic in `Domain/UseCases/`
- [ ] Update ViewModels in `Presentation/ViewModels/` for UI coordination
- [ ] Use constructor injection with protocol abstractions
- [ ] Handle async operations with proper error handling
- [ ] Register operations with OperationCoordinator for tracking

## Testing Requirements
- [ ] Use XcodeBuildMCP tools for build and test execution
- [ ] Always use `describe_ui` before `tap` - never guess coordinates
- [ ] Test background recording with device locking scenarios
- [ ] Validate Live Activity integration when applicable
- [ ] Run both unit tests and integration tests

## Before Completing Task
- [ ] Build successfully with `build_sim`
- [ ] Run relevant test suites
- [ ] Verify no architectural violations (Clean Architecture compliance)
- [ ] Check console logs for errors or warnings
- [ ] Validate background recording functionality if recording-related
- [ ] Document any new patterns or significant changes

## Git Workflow (if requested)
- [ ] Work on feature branch, never main/master
- [ ] Commit with descriptive messages
- [ ] Include Claude Code attribution if creating commits