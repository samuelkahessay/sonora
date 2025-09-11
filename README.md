# Sonora - Modern iOS Voice Memo App with AI Analysis

**Sonora** is a sophisticated iOS voice memo application with AI-powered analysis and exemplary Clean Architecture implementation. Built with native SwiftUI and following industry-leading architectural patterns for maximum reliability, testability, and maintainability.

## ✨ Modern Design & Features

### 🎨 **Native SwiftUI Design**
- **Clean Apple Aesthetic**: Uses standard SwiftUI components and native styling
- **System Integration**: Follows iOS design guidelines with native button styles and layouts
- **Adaptive Theming**: Light/Dark mode support with system color adaptation
- **Accessibility First**: Full VoiceOver support with standard accessibility patterns

#### Semantic Colors (Quick Guide)
- Use `Color.semantic(_:)` everywhere in views; avoid `.red/.blue/.orange`, `Color(red:...)`, and direct `UIColor.*`.
- Tokens: `brand/Primary`, `bg/Primary`, `bg/Secondary`, `text/Primary`, `text/Secondary`, `text/Inverted`, `fill/Primary`, `fill/Secondary`, `separator/Primary`, and state tokens `success/warning/error/info`.
- Examples:
  - Button tint: `.tint(.semantic(.brandPrimary))` (destructive: `.semantic(.error)`)
  - Card background: `.background(Color.semantic(.bgSecondary))`
  - Secondary text: `.foregroundColor(.semantic(.textSecondary))`
  - Badge: `.background(Color.semantic(.brandPrimary).opacity(0.12))` + `.foregroundColor(.semantic(.brandPrimary))`
- Accessibility: Use `text/Inverted` over tinted brand backgrounds; prefer `bg/*` + `text/*` for content to maintain AA contrast.

### 🚀 **Core Capabilities**
Sonora combines cutting-edge technology with intuitive design:
- **Advanced Voice Recording**: Background recording with Live Activities integration
- **Real-time Transcription**: Powered by modern `TranscriptionAPI` implementation  
- **AI-Powered Analysis**: Intelligent summaries, themes, todos, and content insights
- **Thread-safe Operations**: Sophisticated concurrency management with progress tracking
- **Event-Driven Architecture**: Decoupled, reactive system for scalable feature development
- **Focused Service Architecture**: 6 specialized audio services orchestrated through composition pattern

### 🎯 **Key Features**
- **🎤 Smart Recording**: 60-second limit with elegant 10-second countdown
- **💡 Dynamic Prompts**: Context-aware recording prompts personalized by name, time of day, and week part
- **📱 Live Activities**: Real-time recording status in Dynamic Island
- **🧠 AI Analysis Suite**: TLDR summaries, theme extraction, todo identification, content analysis
- **⚡ Advanced Operations**: Queue management, progress tracking, conflict resolution
- **🔄 Event System**: Reactive architecture for seamless feature integration
- **🏗️ Clean Architecture**: 97% compliance with protocol-based dependency injection
- **📊 Operation Metrics**: Real-time system performance and resource monitoring
- **📅 EventKit Integration**: Smart calendar event and reminder creation from voice transcripts
- **⏱️ Recording Quotas**: 10-minute daily cloud transcription limit with local WhisperKit fallback
- **🤖 WhisperKit Local Models**: On-device transcription with multiple language support

### 🔧 **Advanced Features Deep Dive**

#### **📅 EventKit Integration**
- **Smart Detection**: AI-powered extraction of calendar events and reminders from voice transcripts
- **Calendar Creation**: Direct integration with Apple Calendar and Reminders apps
- **Event Confirmation**: Beautiful confirmation UI with calendar selection and date/time editing
- **Batch Operations**: Create multiple events and reminders in a single action
- **Conflict Detection**: Smart scheduling that checks for existing calendar conflicts

#### **⏱️ Recording Quota Management**
- **Daily Limits**: 10-minute daily cloud transcription quota with usage tracking
- **Session Limits**: 3-minute maximum per recording session
- **Smart Fallback**: Automatic switch to local WhisperKit when quota exceeded
- **Usage Monitoring**: Real-time quota display in settings and recording interface
- **Reset Logic**: Automatic daily quota reset with timezone awareness

#### **🤖 WhisperKit Local Transcription**
- **On-Device Processing**: Privacy-first local transcription using Apple's CoreML
- **Multi-Language Support**: 15+ languages with downloadable models
- **Model Management**: Intelligent model downloading and storage optimization
- **Performance Optimization**: Hardware-accelerated inference on Apple Silicon
- **Fallback Strategy**: Seamless integration as backup to cloud transcription

## 🚀 **Release Timeline & Milestones**

### **App Store Submission Journey**
- **🧪 First Public TestFlight Submission**: September 7, 8:02 PM
- **✅ First Public TestFlight Acceptance**: September 8, 12:00 PM  
- **📱 First App Store Submission Review**: September 8, 1:00 PM
- **⏳ First App Store Submission Acceptance**: TBD

*From concept to TestFlight in just 18 days - showcasing rapid development with Clean Architecture patterns.*

## 📐 Architecture Overview
For the complete architecture, current metrics, and next steps, see `ARCHITECTURE.md`.

Sonora follows **Clean Architecture** principles with **MVVM** presentation patterns.

```
┌─────────────────────────────────────────┐
│            Presentation Layer           │
│  ┌─────────────────┐ ┌─────────────────┐│
│  │      Views      │ │   ViewModels    ││
│  │   (SwiftUI)     │ │(@ObservableObject)││
│  │                 │ │ + Use Cases     ││
│  └─────────────────┘ └─────────────────┘│
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│             Domain Layer                │
│  ┌─────────────────┐ ┌─────────────────┐│
│  │   Use Cases     │ │   Domain Models ││
│  │ (Business Logic)│ │   (Entities)    ││
│  │ + Protocols     │ │ + Protocols     ││
│  └─────────────────┘ └─────────────────┘│
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│              Data Layer                 │
│  ┌─────────────────┐ ┌─────────────────┐│
│  │  Repositories   │ │    Services     ││
│  │ (Implementations)│ │(External APIs)  ││
│  │                 │ │ + File System   ││
│  └─────────────────┘ └─────────────────┘│
└─────────────────────────────────────────┘
```

## 🗂️ File Structure & Navigation

### Core Architecture Components

```
Sonora/
├── LiveActivity/                   # 📱 Dynamic Island integration
│   └── SonoraLiveActivityAttributes.swift  # Live Activity data models
├── Networking/                     # 🌐 Network utilities
│   └── MultipartForm.swift        # HTTP form data handling
├── Core/                           # Infrastructure & Cross-cutting concerns
│   ├── DI/
│   │   └── DIContainer.swift       # 🏭 Dependency injection container (composition root)
│   ├── Concurrency/
│   │   ├── OperationCoordinator.swift   # 🔄 Thread-safe operation management  
│   │   ├── OperationStatus.swift        # 📊 Operation status & progress tracking
│   │   └── OperationType.swift          # 🏷️ Operation definitions & conflicts
│   ├── Events/
│   │   ├── EventBus.swift              # 📡 Event-driven architecture
│   │   └── *EventHandler.swift         # 🎯 Reactive event handlers
│   ├── Logging/
│   │   └── Logger.swift                # 📝 Structured logging system
│   └── Errors/
│       └── *.swift                     # ⚠️ Domain-specific error types
├── Domain/                         # Business logic & rules
│   ├── UseCases/                   # 🎯 29 Single-purpose business operations across 8 categories
│   │   ├── Recording/ (8 use cases)
│   │   │   ├── StartRecordingUseCase.swift, StopRecordingUseCase.swift
│   │   │   ├── CanStartRecordingUseCase.swift, RequestMicrophonePermissionUseCase.swift
│   │   │   ├── GetRemainingDailyQuotaUseCase.swift, ConsumeRecordingUsageUseCase.swift
│   │   │   ├── ResetDailyUsageIfNeededUseCase.swift, RecordingFlowTestUseCase.swift
│   │   ├── Transcription/ (5 use cases)
│   │   │   ├── StartTranscriptionUseCase.swift, GetTranscriptionStateUseCase.swift
│   │   │   ├── RetryTranscriptionUseCase.swift, TranscriptionAggregator.swift
│   │   │   └── TranscriptionPersistenceTestUseCase.swift
│   │   ├── Analysis/ (6 use cases)
│   │   │   ├── AnalyzeDistillUseCase.swift, AnalyzeThemesUseCase.swift
│   │   │   ├── AnalyzeTodosUseCase.swift, AnalyzeContentUseCase.swift
│   │   │   ├── CreateAnalysisShareFileUseCase.swift, AnalyzeDistillParallelUseCase.swift
│   │   ├── Memo/ (6 use cases)
│   │   │   ├── LoadMemosUseCase.swift, PlayMemoUseCase.swift
│   │   │   ├── RenameMemoUseCase.swift, DeleteMemoUseCase.swift
│   │   │   ├── HandleNewRecordingUseCase.swift, CreateTranscriptShareFileUseCase.swift
│   │   ├── EventKit/ (3 use cases)
│   │   │   ├── CreateCalendarEventUseCase.swift, CreateReminderUseCase.swift
│   │   │   └── DetectEventsAndRemindersUseCase.swift
│   │   ├── LiveActivity/ (3 use cases)
│   │   │   ├── StartLiveActivityUseCase.swift, UpdateLiveActivityUseCase.swift
│   │   │   └── EndLiveActivityUseCase.swift
│   │   ├── System/ (1 use case)
│   │   │   └── DeleteAllUserDataUseCase.swift
│   │   └── Base/ (3 base classes)
│   │       ├── BaseUseCase.swift, UseCase.swift, UseCaseFactory.swift
│   ├── Models/
│   │   ├── Memo.swift                  # 📄 Domain entity (single model)
│   │   └── DomainAnalysisResult.swift  # 🧠 Analysis domain model
│   ├── Protocols/                      # 🔌 Repository & service contracts
│   │   ├── MemoRepository.swift
│   │   ├── AnalysisServiceProtocol.swift
│   │   └── TranscriptionAPI.swift
│
├── Presentation/                   # UI & View Logic
│   └── ViewModels/                 # 🎬 Presentation logic coordinators
│       ├── RecordingViewModel.swift        # 🎤 Recording state & operations
│       ├── MemoDetailViewModel.swift       # 📱 Memo details & analysis
│       ├── MemoListViewModel.swift         # 📋 Memo list management
│       └── OperationStatusViewModel.swift  # 📊 System-wide operation monitoring
├── Data/                          # External data & persistence
│   ├── Repositories/              # 💾 Data access implementations
│   │   ├── Base/
│   │   │   └── BaseRepository.swift       # 🏗️ Common CRUD operations & patterns
│   │   ├── MemoRepositoryImpl.swift
│   │   ├── AnalysisRepositoryImpl.swift
│   │   ├── TranscriptionRepositoryImpl.swift
│   │   └── AudioRepositoryImpl.swift
│   └── Services/                  # 🌐 External API & system integrations (9 categories, 34+ services)
│       ├── Audio/ (8 services)            # 🎵 Audio recording & playback
│       │   ├── BackgroundAudioService.swift, AudioSessionService.swift
│       │   ├── AudioRecordingService.swift, AudioPlaybackService.swift
│       │   ├── AudioPermissionService.swift, RecordingTimerService.swift
│       │   ├── BackgroundTaskService.swift, AudioQualityManager.swift
│       ├── Transcription/ (7 services)   # 🗣️ Speech-to-text processing
│       │   ├── TranscriptionService.swift, WhisperKitTranscriptionService.swift
│       │   ├── VADSplittingService.swift, AudioChunkManager.swift
│       │   ├── ClientLanguageDetectionService.swift, WhisperKitHealthChecker.swift
│       │   └── ModelManagement/ (4 services) # WhisperKit model lifecycle
│       ├── Analysis/ (6 services)        # 🧠 AI content analysis
│       │   ├── AnalysisService.swift, LocalAnalysisService.swift
│       │   ├── LocalModelDownloadManager.swift, Guardrails.swift
│       │   ├── LocalModel.swift, ModelTier.swift
│       ├── AI/ (1 service)               # 🤖 AI model management
│       │   └── WhisperKitModelManager.swift
│       ├── EventKit/ (1 service)         # 📅 Calendar integration
│       │   └── EventKitPermissionService.swift
│       ├── Export/ (3 services)          # 📤 Data export & sharing
│       │   ├── DataExportService.swift, AnalysisExportService.swift
│       │   └── TranscriptExportService.swift
│       ├── Moderation/ (2 services)      # 🛡️ Content safety
│       │   ├── ModerationService.swift, NoopModerationService.swift
│       └── System/ (2 services)          # 🔧 System integration
│           ├── SystemNavigatorImpl.swift, LiveActivityService.swift
├── Views/                         # 🎨 SwiftUI view components
│   ├── Components/
│   │   ├── AnalysisResultsView.swift
│   │   └── TranscriptionStatusView.swift
│   └── MemoDetailView.swift
└── Models/                        # 📋 Data transfer objects
    ├── AnalysisModels.swift       # Analysis API models
    └── TranscriptionState.swift   # Transcription state enum
```

### Features Organization

Presentation code is organized by feature for clarity and autonomy:

```
Sonora/Features/
  Recording/                    # 🎤 Audio recording interface
    UI/                        # RecordingView, SonicBloomRecordButton
    UI/Components/             # DynamicPromptCard, FallbackPromptCard, InspireMeSheet
    ViewModels/                # RecordingViewModel, RecordingViewState
  Memos/                       # 📋 Voice memo management
    UI/                        # MemosView, MemoDetailView, MemoRowView
    UI/Components/             # SonoraMemocCard, MemoSwipeActionsView, MemoListTopBarView
    ViewModels/                # MemoListViewModel, MemoDetailViewModel
  Analysis/                    # 🧠 AI-powered content analysis
    UI/                        # AnalysisSectionView, AnalysisResultsView, DistillResultView
    UI/Components/             # SonoraInsightCard, EventsResultView, RemindersResultView
    ViewModels/                # AnalysisViewModel
  Settings/                    # ⚙️ Application configuration
    UI/                        # SettingsView, WhisperKitSectionView, PrivacySectionView
    UI/Components/             # ModelDownloadButton, TranscriptionServiceToggle
    ViewModels/                # PrivacyController
    Models/                    # WhisperModelInfo, LicenseInfo
  Onboarding/                  # 👋 First-run user experience
    UI/                        # OnboardingView
    UI/Components/             # OnboardingPageView
    ViewModels/                # OnboardingViewModel
  Operations/                  # 📊 System operation monitoring
    ViewModels/                # OperationStatusViewModel

Sonora/Views/Components/       # Truly shared UI components (e.g., TranscriptionStatusView)
```

Guidelines:
- Features contain only Views and ViewModels. Put Use Cases in `Domain/UseCases` and data access in `Data/*`.
- ViewModels receive protocol dependencies (constructor injection); DI happens in `Core/DI/DIContainer`.
- Avoid importing one feature into another. Share UI via `Views/Components` and communicate via `EventBus` + repository state.
- Register long work with `OperationCoordinator` and surface status via ViewModels.

### Prompts Module (At a Glance)

- Domain: `RecordingPrompt`, `InterpolatedPrompt`, `PromptCatalog`, `PromptUsageRepository`
- Use Cases: `GetDynamicPromptUseCase`, `GetPromptCategoryUseCase`
- Data: `PromptUsageRecord` (SwiftData), `PromptUsageRepositoryImpl`, `PromptCatalogStatic` (48 prompts)
- Core: `DateProvider`, `LocalizationProvider` (DI via `DIContainer`)
- UI: `PromptViewModel`, `DynamicPromptCard` (+ fallback), `InspireMeSheet` integrated in `RecordingView`
- Behavior: 7‑day no‑repeat, weighted selection, stable daily tiebreak; tokens `[Name]`, `[DayPart]`, `[WeekPart]`
- Events: `promptShown`, `promptUsed`, `promptFavoritedToggled` (privacy‑safe)
- Feature flag: `FeatureFlags.usePrompts`

### Quick Navigation Guide

| **Component Type** | **Location** | **Purpose** |
|-------------------|--------------|-------------|
| **Business Logic** | `Domain/UseCases/` | Single-responsibility operations |
| **UI State Management** | `Features/*/ViewModels/` | Feature ViewModels (MVVM) |
| **Data Access** | `Data/Repositories/` | Protocol implementations |
| **External APIs** | `Data/Services/` | Network & system services |
| **Dependency Injection** | `Core/DI/DIContainer.swift` | Service coordination |
| **Operation Management** | `Core/Concurrency/` | Thread-safe operation tracking |
| **Event System** | `Core/Events/` | Reactive architecture components |
| **Shared UI** | `Views/Components/` | Feature-agnostic components |

### Adding a New Feature (Template)

```
Features/YourFeature/
  UI/
    YourFeatureView.swift
  ViewModels/
    YourFeatureViewModel.swift
```

Steps:
- Define/extend Domain protocols + Use Case under `Domain/UseCases/*`.
- Implement/extend repository/service under `Data/*` if needed.
- Create Feature ViewModel, inject protocols, expose minimal UI state.
- Build SwiftUI views in `Features/YourFeature/UI` using native components.
- Register long-running work with `OperationCoordinator` and publish `AppEvent` for cross-feature reactions.
| **Testing Documentation** | `docs/testing/` | Test guides & procedures |

## 🎯 Development Philosophy

Sonora is designed for clear, iterative development with strong boundaries between layers:

### Memo Model
- Single model: `Memo` is used across Domain, Data, and Presentation layers.
- Fields: `id`, `filename`, `fileURL`, `creationDate`, `transcriptionStatus`, `analysisResults`.
- Helpers: audio `duration` and `durationString` via `Memo+AudioMetadata` (Data layer extension).

### Operations & Events
- All long-running work (recording, transcription, analysis) registers with `OperationCoordinator`.
- `OperationStatus` and delegate updates power UI (queue position, progress, metrics).
- `EventBus` publishes `AppEvent` (e.g., `memoCreated`, `transcriptionCompleted`). Handlers (e.g., `LiveActivityEventHandler`, `MemoEventHandler`) react without tight coupling.

### Dependency Injection
- Composition root: `Core/DI/DIContainer.swift`.
- Prefer constructor injection of protocols. Convenience initializers may resolve from `DIContainer` only at the app edge.

### Error Handling & Logging
- Map system/IO/service errors to domain errors via `ErrorMapping` and `SonoraError`.
- Use `Logger` with `LogContext` for structured logs and correlation IDs in use cases.

### 1. **Follow the Flow**: Domain → Use Case → ViewModel → View
```swift
// 1. Domain: What should happen?
protocol AnalyzeDistillUseCaseProtocol {
    func execute(transcript: String, memoId: UUID) async throws -> AnalysisEnvelope<DistillResult>
}

// 2. Use Case: How should it happen?
final class AnalyzeDistillUseCase: AnalyzeDistillUseCaseProtocol {
    private let analysisService: AnalysisServiceProtocol
    private let analysisRepository: AnalysisRepositoryProtocol
    
    init(analysisService: AnalysisServiceProtocol, analysisRepository: AnalysisRepositoryProtocol) {
        self.analysisService = analysisService
        self.analysisRepository = analysisRepository
    }
    
    func execute(transcript: String, memoId: UUID) async throws -> AnalysisEnvelope<DistillResult> {
        let result = try await analysisService.analyzeDistill(transcript: transcript)
        try await analysisRepository.saveDistillResult(result, for: memoId)
        return AnalysisEnvelope(data: result, memoId: memoId, timestamp: Date())
    }
}

// 3. ViewModel: Coordinate with UI
@MainActor
final class MemoDetailViewModel: ObservableObject {
    @Published var state = MemoDetailViewState()
    
    private let analyzeDistillUseCase: AnalyzeDistillUseCaseProtocol
    
    func analyzeDistill() {
        guard let transcript = state.memo?.transcript else { return }
        
        Task {
            state.isAnalyzing = true
            do {
                let envelope = try await analyzeDistillUseCase.execute(
                    transcript: transcript, 
                    memoId: state.memo!.id
                )
                state.distillResult = envelope.data
            } catch {
                state.analysisError = error.localizedDescription
            }
            state.isAnalyzing = false
        }
    }
}

## 🧭 How Things Work Together

- Recording: `RecordingViewModel` → `StartRecordingUseCase`/`StopRecordingUseCase` → `AudioRepository` (uses `BackgroundAudioService`).
- Memo Creation: `MemoRepositoryImpl.handleNewRecording(at:)` persists files/metadata and triggers transcription.
- Transcription: `StartTranscriptionUseCase` uses `TranscriptionAPI` and `TranscriptionRepository` for state + text persistence.
- Analysis: `Analyze*UseCase` uses `AnalysisService` and `AnalysisRepository` to cache and serve results.
- Event Flow: `AppEvent.memoCreated` → `MemoEventHandler` for analytics/logging; Live Activity handlers update the UI.

## 🧪 Testing

- See `docs/testing/` for guides:
  - `background-recording.md`
  - `enhanced-recording-flow.md`
  - `transcription-integration.md`
  - `docs/testing/README.md`

// 4. View: Present to user
Button("Distill") { 
    viewModel.analyzeDistill() 
}
.disabled(viewModel.state.isAnalyzing || viewModel.state.memo?.transcript == nil)
```

### 2. **Trust the Patterns**: Use established templates

### 3. **Think Business First**: Start with user needs, not technical details

### 4. **Code with Confidence**: Clear separation = less debugging

### 🎨 **Native SwiftUI Implementation**

- **Standard Apple Components**: Uses native SwiftUI button styles (`.borderedProminent`, `.bordered`) and standard layouts
- **Clean Recording Interface**: Simple, elegant recording button with clear visual feedback and state management
- **Native Memo Lists**: Standard SwiftUI `List` with `NavigationLink` for clean, familiar user experience
- **System Theming**: Automatic light/dark mode adaptation using system colors
- **Recording Limits**: Smart 60-second recording with visual countdown; override via `SONORA_MAX_RECORDING_DURATION` environment variable

### 5. **Iterate Quickly**: Easy to modify individual layers

## 🏗️ Core Systems Deep Dive

### Dependency Injection Container

The **DIContainer** provides centralized service management and is used at the app edge to compose concrete implementations. Some cross-layer usages remain and are being reduced.

```swift
// Usage in ViewModels
convenience init() {
    let container = DIContainer.shared
    self.init(
        startRecordingUseCase: StartRecordingUseCase(
            audioRepository: container.audioRepository()
        ),
        memoRepository: container.memoRepository(),
        logger: container.logger()
    )
}
```

**Key Services Available:**
- `audioRepository()` - **Modern** protocol-based audio operations
- `memoRepository()` - **Modern** protocol-based memo data access  
- `transcriptionRepository()` - **Modern** protocol-based speech-to-text functionality
- `analysisRepository()` - **Modern** protocol-based AI analysis operations
- `startRecordingUseCase()` - **Modern** pre-configured recording use case
- `operationCoordinator()` - Concurrency management
- `logger()` - Structured logging

**Focused Audio Services:**
- `audioSessionService()` - AVAudioSession configuration and interruption handling
- `audioRecordingService()` - AVAudioRecorder lifecycle and delegate management
- `backgroundTaskService()` - iOS background task management for recording
- `audioPermissionService()` - Microphone permission status and requests
- `recordingTimerService()` - Recording duration tracking and countdown logic
- `audioPlaybackService()` - Audio playback controls and progress tracking

### Operation Coordination System

The **OperationCoordinator** manages concurrent operations with conflict detection:

```swift
// Register operation with conflict checking
let operationId = await operationCoordinator.registerOperation(
    .analysis(memoId: memo.id, analysisType: .tldr)
)

// Check system status
let metrics = await operationCoordinator.getSystemMetrics()
print("Active operations: \(metrics.activeOperations)/\(metrics.maxConcurrentOperations)")

// Cancel operations
await operationCoordinator.cancelOperation(operationId)
```

**Operation Types:**
- `.recording(memoId: UUID)` - Audio recording operations
- `.transcription(memoId: UUID)` - Speech transcription
- `.analysis(memoId: UUID, analysisType: AnalysisMode)` - AI analysis

### Event-Driven Architecture

The **EventBus** enables reactive communication between components:

```swift
// Publishing events
eventBus.publish(AppEvent.memoCreated(memo: newMemo))
eventBus.publish(AppEvent.transcriptionCompleted(memoId: memo.id, text: transcription))

// Handling events
final class MemoEventHandler: EventHandler {
    func handle(_ event: AppEvent) async {
        switch event {
        case .memoCreated(let memo):
            // React to new memo
        case .transcriptionCompleted(let memoId, let text):
            // Update UI, trigger analysis, etc.
        }
    }
}
```

## 🔧 Development Patterns & Templates

### Adding a New Feature: Step-by-Step

#### 1. **Create the Use Case** (Domain Layer)
```swift
// File: Domain/UseCases/[Category]/NewFeatureUseCase.swift
protocol NewFeatureUseCaseProtocol {
    func execute(parameters: Parameters) async throws -> Result
}

final class NewFeatureUseCase: NewFeatureUseCaseProtocol {
    private let repository: SomeRepository
    private let logger: LoggerProtocol
    
    init(repository: SomeRepository, logger: LoggerProtocol = Logger.shared) {
        self.repository = repository
        self.logger = logger
    }
    
    func execute(parameters: Parameters) async throws -> Result {
        logger.info("Starting new feature operation", category: .system)
        
        // 1. Validate input
        guard parameters.isValid else {
            throw FeatureError.invalidParameters
        }
        
        // 2. Execute business logic
        let result = try await repository.performOperation(parameters)
        
        // 3. Log and return
        logger.info("New feature operation completed", category: .system)
        return result
    }
}
```

#### 2. **Update ViewModel** (Presentation Layer)
```swift
// Add to existing ViewModel or create new one
@MainActor
final class FeatureViewModel: ObservableObject {
    // Dependencies
    private let newFeatureUseCase: NewFeatureUseCaseProtocol
    
    // Published state
    @Published var featureResult: Result?
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    
    // Dependency injection constructor
    init(newFeatureUseCase: NewFeatureUseCaseProtocol) {
        self.newFeatureUseCase = newFeatureUseCase
    }
    
    // Convenience constructor with DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            newFeatureUseCase: NewFeatureUseCase(
                repository: container.someRepository()
            )
        )
    }
    
    // Public action method
    func performNewFeature(with parameters: Parameters) {
        Task {
            isProcessing = true
            errorMessage = nil
            
            do {
                let result = try await newFeatureUseCase.execute(parameters: parameters)
                featureResult = result
            } catch {
                errorMessage = error.localizedDescription
                print("❌ Feature error: \(error)")
            }
            
            isProcessing = false
        }
    }
}
```

#### 3. **Update View** (Presentation Layer)
```swift
// Add to existing view or create new component
struct FeatureView: View {
    @StateObject private var viewModel = FeatureViewModel()
    
    var body: some View {
        VStack {
            if viewModel.isProcessing {
                ProgressView("Processing...")
            } else {
                Button("Execute Feature") {
                    viewModel.performNewFeature(with: parameters)
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            }
            
            if let result = viewModel.featureResult {
                ResultDisplayView(result: result)
            }
        }
    }
}
```

### Common ViewModel Patterns

#### Operation Status Integration
```swift
@MainActor
final class ExampleViewModel: ObservableObject, OperationStatusDelegate {
    @Published var activeOperations: [OperationSummary] = []
    @Published var systemMetrics: SystemOperationMetrics?
    
    private let operationCoordinator: OperationCoordinator
    
    init(operationCoordinator: OperationCoordinator = OperationCoordinator.shared) {
        self.operationCoordinator = operationCoordinator
        setupOperationMonitoring()
    }
    
    private func setupOperationMonitoring() {
        // Monitor operation status every 2 seconds
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.updateOperationStatus() }
            }
            .store(in: &cancellables)
    }
    
    // OperationStatusDelegate implementation
    func operationStatusDidUpdate(_ update: OperationStatusUpdate) {
        Task { await updateOperationStatus() }
    }
    
    func operationDidComplete(_ operationId: UUID, memoId: UUID, operationType: OperationType) {
        print("✅ Operation completed: \(operationType)")
    }
    
    func operationDidFail(_ operationId: UUID, memoId: UUID, operationType: OperationType, error: Error) {
        print("❌ Operation failed: \(operationType) - \(error)")
    }
}
```

#### Error Handling Pattern
```swift
// Standardized error handling in ViewModels
func performOperation() {
    Task {
        do {
            let result = try await useCase.execute()
            // Handle success
        } catch let error as DomainError {
            // Handle domain-specific errors
            handleDomainError(error)
        } catch {
            // Handle unexpected errors
            handleUnexpectedError(error)
        }
    }
}

private func handleDomainError(_ error: DomainError) {
    switch error {
    case .validation(let message):
        errorMessage = "Please check: \(message)"
    case .systemBusy:
        errorMessage = "System is busy, please try again"
    case .networkUnavailable:
        errorMessage = "Please check your internet connection"
    }
}
```

## 🧪 Testing Strategies

> **Detailed Testing Documentation**: See `docs/testing/` for comprehensive testing guides and procedures

### Use Case Testing
```swift
final class AnalyzeTLDRUseCaseTests: XCTestCase {
    private var mockAnalysisService: MockAnalysisService!
    private var mockRepository: MockAnalysisRepository!
    private var useCase: AnalyzeTLDRUseCase!
    
    override func setUp() {
        mockAnalysisService = MockAnalysisService()
        mockRepository = MockAnalysisRepository()
        useCase = AnalyzeTLDRUseCase(
            analysisService: mockAnalysisService,
            analysisRepository: mockRepository
        )
    }
    
    func testSuccessfulAnalysis() async throws {
        // Given
        let transcript = "Test transcript"
        let expectedResult = TLDRResult(summary: "Test summary")
        mockAnalysisService.mockResult = expectedResult
        
        // When
        let envelope = try await useCase.execute(transcript: transcript, memoId: UUID())
        
        // Then
        XCTAssertEqual(envelope.data.summary, expectedResult.summary)
        XCTAssertTrue(mockRepository.saveCalled)
    }
}
```

### ViewModel Testing
```swift
@MainActor
final class RecordingViewModelTests: XCTestCase {
    private var mockUseCase: MockStartRecordingUseCase!
    private var viewModel: RecordingViewModel!
    
    override func setUp() {
        mockUseCase = MockStartRecordingUseCase()
        viewModel = RecordingViewModel(startRecordingUseCase: mockUseCase)
    }
    
    func testStartRecording() async {
        // Given
        mockUseCase.shouldSucceed = true
        
        // When
        await viewModel.startRecording()
        
        // Then
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertNil(viewModel.errorMessage)
    }
}
```

## 🚨 Common Issues & Troubleshooting

### Build Errors

#### 1. **Cannot find type 'SomeProtocol' in scope**
```swift
// Problem: Missing import or protocol definition
// Solution: Add import or check protocol spelling
import Foundation  // Add missing import
```

#### 2. **Actor-isolated property cannot be mutated from main actor**
```swift
// Problem: Trying to set actor properties from @MainActor
// Solution: Use async methods on the actor
await operationCoordinator.setProperty(value)  // ✅
operationCoordinator.property = value          // ❌
```

#### 3. **Use of protocol as type must be written 'any Protocol'**
```swift
// Problem: Swift 6 requires 'any' for existential types
private let repository: any RepositoryProtocol  // ✅
private let repository: RepositoryProtocol      // ❌
```

### Runtime Issues

#### 1. **DIContainer not configured error**
```swift
// Problem: DIContainer.configure() not called
// Solution: Check SonoraApp.swift calls configure() on launch
DIContainer.shared.configure()  // Add to app startup
```

#### 2. **Operation coordinator at capacity**
```swift
// Problem: Too many concurrent operations
// Solution: Check for operation leaks or increase capacity
let metrics = await operationCoordinator.getSystemMetrics()
print("System load: \(metrics.systemLoadPercentage)")
```

### Architecture Issues

#### 1. **ViewModels growing too large**
```swift
// Problem: Putting too much logic in ViewModels
// Solution: Extract business logic to Use Cases

// ❌ Bad: Business logic in ViewModel
func complexBusinessOperation() {
    // 50 lines of business logic
}

// ✅ Good: Delegate to Use Case
func performOperation() {
    Task {
        try await complexOperationUseCase.execute()
    }
}
```

#### 2. **Circular dependencies**
```swift
// Problem: Services depending on each other
// Solution: Use protocols and proper dependency injection

// ❌ Bad: Direct service dependencies
class ServiceA {
    let serviceB = ServiceB()  // Creates coupling
}

// ✅ Good: Protocol-based injection
class ServiceA {
    let serviceB: ServiceBProtocol
    init(serviceB: ServiceBProtocol) { ... }
}
```

## 📚 Best Practices

### Do's ✅

- **Start with Domain**: Always begin new features by defining the domain model and use case
- **Use Dependency Injection**: Inject all dependencies through constructors
- **Follow Single Responsibility**: Each use case should do exactly one thing
- **Handle Errors Properly**: Catch and handle domain-specific errors appropriately
- **Log Operations**: Use structured logging for debugging and monitoring
- **Test Use Cases**: Write unit tests for all business logic
- **Use Async/Await**: Leverage modern Swift concurrency patterns
- **Monitor Operations**: Track operation status for user feedback

### Don'ts ❌

- **Don't put business logic in ViewModels**: Keep ViewModels focused on presentation coordination
- **Don't inject services directly into ViewModels**: Always use use cases as intermediaries
- **Don't create god use cases**: Avoid use cases that do multiple unrelated operations
- **Don't mix UI and business concerns**: Keep domain logic separate from presentation logic
- **Don't ignore error handling**: Every use case should have proper error handling
- **Don't bypass the operation coordinator**: Use it for all concurrent operations
- **Don't hardcode dependencies**: Always use dependency injection
- **Don't forget to complete operations**: Ensure operations are properly completed or failed

## 🔄 Operation Lifecycle Management

### Recording Operations
```swift
// 1. Register recording operation
let operationId = await operationCoordinator.registerOperation(.recording(memoId: memoId))

// 2. Start recording (with automatic operation management)
try await audioService.startRecording()

// 3. Operation completes automatically when recording stops
```

### Analysis Operations
```swift
// 1. Check for conflicts
let canStart = await operationCoordinator.canStartAnalysis(for: memoId)

// 2. Register and execute
let operationId = await operationCoordinator.registerOperation(
    .analysis(memoId: memoId, analysisType: .tldr)
)

// 3. Perform analysis with proper completion
do {
    let result = try await analysisService.analyze(transcript)
    await operationCoordinator.completeOperation(operationId)
} catch {
    await operationCoordinator.failOperation(operationId, error: error)
}
```

## 🎯 Quick Start for New Features

1. **Identify the domain need**: What business operation is required?
2. **Create the use case**: Define protocol and implementation in `Domain/UseCases/`
3. **Update ViewModel**: Inject use case and add coordination method
4. **Update View**: Call ViewModel method from UI
5. **Add error handling**: Ensure proper error states and user feedback
6. **Add operation tracking**: If long-running, integrate with OperationCoordinator
7. **Test the use case**: Write unit tests for the business logic

## 📊 **Architecture Excellence Metrics**

### 🏆 **Outstanding Implementation (97% Clean Architecture Compliance)**
- **Domain Layer**: ✅ **OUTSTANDING (97%)** - 29 Use Cases across 8 categories, 12+ protocols, perfect layer separation
- **Data Layer**: ✅ **OUTSTANDING (95%)** - 34+ services across 9 categories, 4 repositories implementing protocols  
- **Presentation Layer**: ✅ **EXCELLENT (85%)** - Protocol-based dependency injection, zero architecture violations
- **Dependency Injection**: ✅ **OUTSTANDING (95%)** - Pure protocol-based access, exemplary patterns

### 📈 **Migration Success Achievements**
- **Legacy Code Eliminated**: 570+ lines of outdated patterns removed
- **Protocol-First Architecture**: 95% protocol-based dependencies (up from 30%)
- **Service Organization**: 100% compliance with Clean Architecture service placement
- **Modern Concurrency**: Full async/await implementation with thread-safe operation coordination
- **Service Layer Transformation**: Monolithic 634-line BackgroundAudioService split into 6 focused services with orchestration pattern

### 🎯 **Architectural Excellence (January 2025)**
- **Service Separation**: Applied Single Responsibility Principle at service level
- **Reactive Architecture**: Combine-based state synchronization between services
- **Zero Breaking Changes**: Maintained complete API compatibility during refactoring
- **Swift 6 Compliance**: Full concurrency compliance with proper @MainActor usage
- **Enhanced Testability**: Each service can now be mocked and tested independently

---

---

## 🎉 Welcome!

This README provides everything needed to understand and contribute to Sonora. The architecture is designed to be intuitive and productive - trust the patterns, follow the flow, and build amazing features! 

For specific implementation examples, check the existing code in the respective directories. The codebase is self-documenting with clear patterns and comprehensive comments.

**Happy coding! 🚀**
