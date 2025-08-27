# Claude Code Development Guide for Sonora

**Sonora** is a Swift iOS voice memo app with AI analysis, built using **Clean Architecture + MVVM** patterns in a hybrid legacy/modern state.

## 📐 Architecture Quick Reference

```
┌─────────────────────────────────────────┐
│            Presentation Layer           │ 🔄 HYBRID
│  ┌─────────────────┐ ┌─────────────────┐│
│  │      Views      │ │   ViewModels    ││
│  │   (SwiftUI)     │ │ + Use Cases     ││
│  └─────────────────┘ └─────────────────┘│
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│             Domain Layer                │ ✅ COMPLETE
│  ┌─────────────────┐ ┌─────────────────┐│
│  │   Use Cases     │ │   Domain Models ││
│  │ (Business Logic)│ │   (Entities)    ││
│  └─────────────────┘ └─────────────────┘│
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│              Data Layer                 │ 🔄 HYBRID
│  ┌─────────────────┐ ┌─────────────────┐│
│  │  Repositories   │ │ Legacy Services ││
│  │   (Protocols)   │ │ + New Services  ││
│  └─────────────────┘ └─────────────────┘│
└─────────────────────────────────────────┘
```

## 🗂️ File Navigation Guide

| **Component Type** | **Location** | **Purpose** |
|-------------------|--------------|-------------|
| **Business Logic** | `Domain/UseCases/` | Single-responsibility operations |
| **UI State** | `Presentation/ViewModels/` | ObservableObject coordinators |
| **Data Access** | `Data/Repositories/` | Protocol implementations |
| **External APIs** | `Data/Services/` & root services | Network & system services |
| **DI Container** | `Core/DI/DIContainer.swift` | Service coordination |
| **Operation Management** | `Core/Concurrency/` | Thread-safe operation tracking |

```
Sonora/
├── Core/                      # Infrastructure
│   ├── DI/DIContainer.swift   # 🏭 Dependency injection (hybrid legacy/modern)
│   ├── Concurrency/           # 🔄 Operation coordination
│   ├── Events/                # 📡 Event-driven architecture
│   └── Logging/Logger.swift   # 📝 Structured logging
├── Domain/                    # ✅ Complete business logic
│   ├── UseCases/              # 🎯 Recording, Transcription, Analysis, Memo
│   ├── Models/                # 📄 Domain entities
│   └── Protocols/             # 🔌 Repository contracts
├── Presentation/ViewModels/   # 🎬 UI coordinators (hybrid patterns)
├── Data/Repositories/         # 💾 Modern data access
└── [Root Services]            # ⚠️ Legacy services (gradual migration)
```

## 🚀 Development Patterns

### Adding New Features (Follow This Flow)

#### 1. **Create Use Case** (Domain Layer)
```swift
// Domain/UseCases/{Category}/NewFeatureUseCase.swift
protocol NewFeatureUseCaseProtocol {
    func execute(parameters: Parameters) async throws -> Result
}

final class NewFeatureUseCase: NewFeatureUseCaseProtocol {
    private let repository: SomeRepository
    
    init(repository: SomeRepository) {
        self.repository = repository
    }
    
    func execute(parameters: Parameters) async throws -> Result {
        // 1. Validate input
        // 2. Execute business logic  
        // 3. Return result
    }
}
```

#### 2. **Update ViewModel** (Presentation Layer)
```swift
// Add to existing ViewModel or create new one
@MainActor
final class FeatureViewModel: ObservableObject {
    private let newFeatureUseCase: NewFeatureUseCaseProtocol
    @Published var result: Result?
    
    // Dependency injection via DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(newFeatureUseCase: NewFeatureUseCase(
            repository: container.someRepository()
        ))
    }
    
    func performFeature() {
        Task {
            result = try await newFeatureUseCase.execute(...)
        }
    }
}
```

#### 3. **Update View** (Presentation Layer)
```swift
Button("Execute Feature") { viewModel.performFeature() }
```

## 🏗️ Dependency Injection (Hybrid State)

**DIContainer provides both legacy and modern access:**

```swift
let container = DIContainer.shared

// Modern Protocol-Based (Preferred)
let repository = container.memoRepository()           // MemoRepository protocol
let transcriptionRepo = container.transcriptionRepository()

// Legacy Concrete Access (Transitional)
let audioRecorder = container.audioRecorder()        // Concrete AudioRecorder
let memoStore = container.memoStore()                 // Concrete MemoStore
```

## ⚡ Async/Await Patterns

**Modern Use Cases:** All async/await
```swift
try await startRecordingUseCase.execute()
let result = try await analysisUseCase.execute(transcript: text, memoId: id)
```

**MainActor for UI Updates:**
```swift
await MainActor.run {
    self.isLoading = false
    self.result = data
}
```

**OperationStatusDelegate methods are async:**
```swift
func operationDidComplete(_ id: UUID, memoId: UUID, type: OperationType) async {
    // Handle completion
}
```

## 🧪 Testing Best Practices

### UI Testing with XcodeBuildMCP
- **Always use `describe_ui` before `tap`** - Never guess coordinates
- Get precise coordinates: `describe_ui({ simulatorUuid: "UUID" })`
- Common commands:
  - Build: `build_sim({ projectPath: '/.../project.xcodeproj', scheme: 'Sonora', simulatorName: 'iPhone 16' })`
  - Launch: `launch_app_sim({ simulatorName: 'iPhone 16', bundleId: 'com.samuelkahessay.Sonora' })`

### Test Classes Available
- `RecordingFlowTestUseCase` - Background recording tests
- `TranscriptionPersistenceTestUseCase` - Repository persistence tests

**Testing docs**: See `docs/testing/` for detailed guides

## ⚠️ Important Implementation Notes

### Recording State Management
- `RecordingViewModel` sets `isRecording = false` immediately for responsive UI
- Error handling reverts state if operations fail
- Use `await MainActor.run` for UI updates from background contexts

### SwiftUI TabView Requirement  
**Critical**: TabView must be root view without wrapper containers (VStack, ZStack) for proper touch handling

### Known Fixed Issues (Reference Only)
- Recording button state management: RecordingViewModel.swift:314-339
- OperationCoordinator async delegate calls: OperationCoordinator.swift:458-472
- Swift 6 concurrency protocol conformance ✅

## 🔧 Common Commands

**Build & Test:**
```bash
# Build for simulator
build_sim({ projectPath: '/Users/.../Sonora.xcodeproj', scheme: 'Sonora', simulatorName: 'iPhone 16' })

# Launch app
launch_app_sim({ simulatorName: 'iPhone 16', bundleId: 'com.samuelkahessay.Sonora' })
```

**Architecture Status:** Hybrid legacy/modern - Domain layer complete, gradual migration ongoing
**Testing Coverage:** 45% implemented with expanding test classes
**Key Legacy Components:** AudioRecorder, MemoStore, TranscriptionManager (see LEGACY.md)

---

For comprehensive architecture details, see README.md  
For testing procedures, see docs/testing/  
For migration status, see ARCHITECTURE_MIGRATION.md