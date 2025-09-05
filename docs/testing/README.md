# Testing Documentation

## Active Testing Guides

### Core Testing Infrastructure
- **[Background Recording Tests](background-recording.md)** - Test background recording functionality with `RecordingFlowTestUseCase`
- **[Enhanced Recording Flow](enhanced-recording-flow.md)** - Comprehensive recording flow testing and validation
- **[Transcription Integration](transcription-integration.md)** - Repository persistence testing with `TranscriptionPersistenceTestUseCase`

### Available Test Classes
- `RecordingFlowTestUseCase` - Located in `Domain/UseCases/Recording/`
- `TranscriptionPersistenceTestUseCase` - Located in `Domain/UseCases/Transcription/`

## Historical Documentation

Historical notes have been consolidated into a single archive for brevity:
- **[ARCHIVE.md](../archive/ARCHIVE.md)** — compact summaries of past fixes (RESOLVED)

## Quick Testing Commands

**UI Testing with XcodeBuildMCP:**
```bash
# Always use describe_ui before tap for precise coordinates
describe_ui({ simulatorUuid: "UUID" })

# Build and launch
build_sim({ projectPath: '/.../Sonora.xcodeproj', scheme: 'Sonora', simulatorName: 'iPhone 16' })
launch_app_sim({ simulatorName: 'iPhone 16', bundleId: 'com.samuelkahessay.Sonora' })
```

**Running Test Classes:**
```swift
// Background recording test
let testCase = await RecordingFlowTestUseCase.create()
await testCase.testCompleteRecordingFlow()

// Transcription persistence test  
let persistenceTest = await TranscriptionPersistenceTestUseCase.create()
await persistenceTest.testTranscriptionPersistence()
```

---

For architectural context, see main [README.md](../../README.md) and [ARCHITECTURE_MIGRATION.md](../../ARCHITECTURE_MIGRATION.md)
