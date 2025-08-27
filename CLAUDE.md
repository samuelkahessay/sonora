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

## 📋 Architecture Migration Status (December 2025)

### **COMPLETED PHASES** ✅

#### **Phase 1: Transcription Pipeline Modernization** ✅ **COMPLETE**
- ✅ Created `TranscriptionAPI` protocol for clean abstraction
- ✅ Made `TranscriptionService` conform to `TranscriptionAPI` 
- ✅ Updated all Use Cases to use protocol instead of concrete implementation
- ✅ Added `TranscriptionAPI` to `DIContainer` with protocol-based access
- ✅ Updated ViewModels to use dependency injection through container

#### **Phase 2: Recording Pipeline Modernization** ✅ **COMPLETE**
- ✅ **AudioRepository Protocol Expansion**: Added recording methods (`startRecording()`, `stopRecording()`, `isRecording`, etc.)
- ✅ **AudioRepositoryImpl Enhancement**: Full protocol conformance using `BackgroundAudioService`
- ✅ **Use Cases Refactored**: Removed type casting anti-pattern, protocol-only interfaces
- ✅ **RecordingViewModel Modernization**: Uses `AudioRepository` protocol instead of legacy `AudioRecordingService`
- ✅ **Legacy Component Removal**: Deleted `AudioRecorder.swift`, `AudioRecordingService.swift`, `AudioRecordingServiceWrapper.swift`
- ✅ **DIContainer Cleanup**: Removed all `AudioRecordingService` references, added `audioRepository()` method
- ✅ **Recording Bug Fix**: Fixed async permission race condition with synchronous permission checks and enhanced error logging

### **PENDING PHASES** 🚧

#### **Phase 3: Memo Management Modernization** 📋 **NEXT**
- 🔄 **Extract Memo Model**: Move from root to `Domain/Models/`
- 🔄 **Delete MemoStore Logic**: Replace with pure repository pattern
- 🔄 **Update DIContainer**: Remove `MemoStore` dependencies
- 🔄 **Repository Consolidation**: Ensure single source of truth through `MemoRepository`

#### **Phase 4: Service Layer Reorganization** 🗂️ **FUTURE**
- 🔄 **Reorganize Services**: Move remaining services to `Data/Services/`
- 🔄 **Remove TranscriptionManager**: Replace with direct repository access
- 🔄 **Consolidate Service Interfaces**: Ensure all services have protocol abstractions

#### **Phase 5: Final Cleanup** 🧹 **FUTURE** 
- 🔄 **Remove Legacy Protocols**: Clean up unused protocol definitions
- 🔄 **DIContainer Simplification**: Remove hybrid legacy/modern access patterns
- 🔄 **Architecture Validation**: Ensure complete Clean Architecture compliance

### **CURRENT ARCHITECTURE STATE** 🎯

**Domain Layer**: ✅ **Complete** - Pure business logic with protocol-based repositories
**Data Layer**: 🔄 **Modern** - AudioRepository ✅, TranscriptionRepository ✅, MemoRepository 🔄 (uses MemoStore)  
**Presentation Layer**: 🔄 **Hybrid** - RecordingViewModel ✅ modern, others still use legacy patterns

**Key Modern Components:**
- `AudioRepository` + `AudioRepositoryImpl` (uses `BackgroundAudioService`)
- `TranscriptionAPI` + `TranscriptionService` 
- All Use Cases are protocol-based with proper dependency injection
- `DIContainer` provides both modern protocol access and legacy concrete access

**Remaining Legacy Components:**
- `MemoStore` (scheduled for Phase 3 removal)
- `TranscriptionManager` (scheduled for Phase 4 removal)  
- Some ViewModels still use direct service instantiation (gradual migration)

### **MIGRATION PRIORITIES** ⚡
1. **Phase 3** - Most impactful: Removes largest legacy component (`MemoStore`)
2. **Recording System** - ✅ **Fully Modernized** (supports background recording, proper error handling)
3. **Transcription System** - ✅ **Fully Modernized** (protocol-based, async/await)
4. **Analysis System** - ✅ **Fully Modernized** (repository pattern, caching)

---

For comprehensive architecture details, see README.md  
For testing procedures, see docs/testing/  
For migration status, see ARCHITECTURE_MIGRATION.md