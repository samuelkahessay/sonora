# Sonora Development Commands

## Build & Test Commands
```bash
# Build for simulator (primary development)
mcp__XcodeBuildMCP__build_sim({
  projectPath: '/path/to/Sonora.xcodeproj', 
  scheme: 'Sonora', 
  simulatorName: 'iPhone 16'
})

# Run tests on simulator
mcp__XcodeBuildMCP__test_sim({
  projectPath: '/path/to/Sonora.xcodeproj',
  scheme: 'Sonora',
  simulatorName: 'iPhone 16'
})

# Swift Package operations
mcp__XcodeBuildMCP__swift_package_test({ packagePath: '/path/to/package' })
mcp__XcodeBuildMCP__swift_package_build({ packagePath: '/path/to/package' })
```

## UI Testing with XcodeBuildMCP
```bash
# ALWAYS get coordinates before tapping - never guess
mcp__XcodeBuildMCP__describe_ui({ simulatorUuid: "UUID" })
mcp__XcodeBuildMCP__tap({ simulatorUuid: "UUID", x: 123, y: 456 })
mcp__XcodeBuildMCP__screenshot({ simulatorUuid: "UUID" })
```

## Key File Locations
- **Use Cases**: `Domain/UseCases/` - Business logic (29 use cases)
- **ViewModels**: `Presentation/ViewModels/` - UI coordination
- **Repositories**: `Data/Repositories/` - Data access implementations
- **Services**: `Data/Services/` - External API integrations
- **DI Container**: `Core/DI/DIContainer.swift` - Service composition root
- **Testing**: `docs/testing/` - Test procedures and documentation

## System Commands (Darwin)
- `ls`, `cd`, `grep` (prefer Serena's tools for project analysis)
- `git status && git branch` - Always check before starting work
- `find_symbol`, `read_file` - Use Serena's tools for code exploration

## Development Workflow
1. Check git status: `git status && git branch`
2. Activate project: `mcp__serena__activate_project({ project: "Sonora" })`
3. Explore code: Use Serena's `find_symbol`, `read_file`, `search_for_pattern`
4. Build: Use XcodeBuildMCP tools
5. Test: Run comprehensive test suites

## Environment Variables for Testing
- `SONORA_MAX_RECORDING_DURATION=120` - Override 60s recording limit
- Use in Xcode scheme environment variables for extended recording tests