# Claude Development Notes for Sonora

## Testing Best Practices

### UI Testing with XcodeBuildMCP
- **Always use `describe_ui` before `tap`**: Never guess coordinates from screenshots
- Use `describe_ui({ simulatorUuid: "UUID" })` to get precise element coordinates and frame data
- Only use the coordinates returned by `describe_ui` for accurate automation
- This prevents failed taps and ensures reliable UI interactions

### Common Commands
- Build: `build_sim({ projectPath: '/path/to/project.xcodeproj', scheme: 'SchemeName', simulatorName: 'iPhone 16' })`
- Launch: `launch_app_sim({ simulatorName: 'iPhone 16', bundleId: 'bundle.identifier' })`
- UI Description: `describe_ui({ simulatorUuid: 'simulator-uuid' })`
- Screenshot: `screenshot({ simulatorUuid: 'simulator-uuid' })`

## Architecture Notes

### Recording State Management
- `RecordingViewModel` manages UI state with immediate updates
- `isRecording` is set to `false` immediately when stop is requested for responsive UI
- Proper error handling reverts state if stop operation fails

### Dependency Injection
- `DIContainer.shared` provides all services
- `MemoListViewModel` uses convenience initializer with proper DI setup
- Clean Architecture pattern with Use Cases for business logic

### Async/Await Pattern
- `OperationStatusDelegate` methods are async to support MainActor isolation
- Use `await MainActor.run` when updating UI properties from background contexts

## Known Issues Fixed
- Recording stop button state management (RecordingViewModel.swift:314-339)
- OperationCoordinator async delegate method calls (OperationCoordinator.swift:458-472)
- Protocol conformance for Swift 6 strict concurrency

## Memos Tab Navigation Bug Analysis

### Bug Description
The Memos tab in TabView doesn't respond to direct taps, preventing navigation to the memos list.

### Root Cause Discovered
The VStack wrapper around TabView (added for debug button) breaks TabView's touch handling. TabView must be the root view for proper touch detection.

### What We Tried (Chronological)

#### ✅ Successful Fixes
1. **Fixed RecordingViewModel State Management**
   - Issue: Recording button wasn't updating UI when stop was triggered
   - Solution: Set `isRecording = false` immediately in `stopRecording()` (RecordingViewModel.swift:314)
   - Result: UI now updates immediately

2. **Fixed Async Protocol Conformance**
   - Issue: OperationStatusDelegate methods weren't async-compatible with MainActor
   - Solution: Made delegate methods async (OperationStatus.swift:236-241)
   - Result: Proper async/await flow for UI updates

3. **Fixed MemoListViewModel Dependency Injection**
   - Issue: Missing AnalysisRepository and wrong TranscriptionService types
   - Solution: Added proper dependencies in convenience init (MemoListViewModel.swift:85-109)
   - Result: ViewModel initializes without errors

4. **Deferred Heavy Operations in MemoListViewModel**
   - Issue: Timer.publish() in init was blocking view initialization
   - Solution: Moved `setupBindings()` and `loadMemos()` to `onViewAppear()` (MemoListViewModel.swift:71-72)
   - Result: Prevented initialization blocking

5. **Added MemoStore Environment Object**
   - Issue: MemosView expected @EnvironmentObject but it wasn't provided
   - Solution: Added @StateObject in SonoraApp.swift and `.environmentObject(memoStore)`
   - Result: Environment object properly injected

6. **Removed Crashing Environment Object References**
   - Issue: App crashed when navigating to Memos (went to home screen)
   - Solution: Removed `@EnvironmentObject var memoStore` from MemosView and MemoRowView
   - Result: Crash fixed, navigation works programmatically

#### ❌ Failed Attempts
1. **Direct Tab Taps Don't Work**
   - Tapping the Memos tab in the tab bar has no effect
   - No logs show selection change
   - TabView isn't receiving touch events

2. **describe_ui Returns Empty**
   - The XcodeBuildMCP describe_ui function returns empty accessibility hierarchy
   - Can't get precise coordinates for UI elements

#### 🔍 Key Discovery
**Programmatic navigation works but touch doesn't:**
- Debug button that sets `selectedTab = 1` successfully navigates to Memos
- Direct taps on tab bar don't register at all
- Logs show: "🔄 TabView: Selection changed from 0 to 1" only with button, not taps
- **Root cause: VStack wrapper around TabView breaks touch handling**

### Current State
```swift
// ContentView.swift - PROBLEMATIC STRUCTURE
var body: some View {
    VStack(spacing: 0) {  // THIS BREAKS TAB TOUCH HANDLING
        #if DEBUG
        Button("Debug: Switch to Memos Tab") { ... }
        #endif
        
        TabView(selection: $selectedTab) { ... }
    }
}
```

### Solution Required
Remove the VStack wrapper and find alternative way to add debug UI that doesn't interfere with TabView's touch handling. TabView must be the root view in body for proper touch detection.

### Diagnostic Logging Added
- ContentView: Tab selection changes logged
- MemosView: Initialization logged
- MemoListViewModel: View lifecycle logged