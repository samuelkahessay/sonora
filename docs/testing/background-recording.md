# Background Recording Test Instructions

> **Status**: ACTIVE TESTING DOCUMENTATION
> **Test Classes**: `RecordingFlowTestUseCase` (implemented)
> **Purpose**: Verify background recording functionality with AudioRepositoryImpl

## Testing the Updated AudioRepositoryImpl with BackgroundAudioService

### What Was Updated:

1. **Integrated BackgroundAudioService** into `AudioRepositoryImpl`
2. **Added proper session configuration** that maintains `.playAndRecord` during recording
3. **Added background task management** with automatic task lifecycle
4. **Ensured single recorder instance** managed by BackgroundAudioService
5. **Added comprehensive error handling** and state management

### How to Test Background Recording:

#### Method 1: Using the Test Function
```swift
// In your app, call this method from any view or service:
let audioRepo = AudioRepositoryImpl()
Task {
    await audioRepo.testBackgroundRecording()
}
```

#### Method 2: Manual Testing
```swift
let audioRepo = AudioRepositoryImpl()

// Start recording
Task {
    do {
        try await audioRepo.startRecording()
        print("Recording started: \(audioRepo.isRecording)")
        print("Background task active: \(audioRepo.isBackgroundTaskActive)")
    } catch {
        print("Failed to start recording: \(error)")
    }
}

// Later, stop recording
audioRepo.stopRecording()
```

### Test Procedure:

1. **Start the test** by calling `testBackgroundRecording()` or manually starting recording
2. **Lock your iPhone** while recording is active
3. **Wait for at least 30 seconds** with the device locked
4. **Unlock the device** and check the console logs
5. **Verify recording continued** by checking the logged recording times

### What to Look For:

#### ✅ **Success Indicators:**
- Recording continues when device is locked
- Background task remains active (`isBackgroundTaskActive = true`)
- Recording time increases even while locked
- No audio session interruption errors

#### ❌ **Failure Indicators:**
- Recording stops when device is locked
- Background task becomes inactive
- Audio session errors in console
- Recording time stops incrementing

### Console Output Example:
```
🧪 AudioRepositoryImpl: Starting background recording test
🎵 BackgroundAudioService: Recording started successfully
🧪 Background task active: true
🧪 AudioRepositoryImpl: Test 2s - Recording: true, Time: 2.1s, Background: true
🧪 AudioRepositoryImpl: Test 4s - Recording: true, Time: 4.2s, Background: true
[Lock device here]
🧪 AudioRepositoryImpl: Test 6s - Recording: true, Time: 6.1s, Background: true
🧪 AudioRepositoryImpl: Test 8s - Recording: true, Time: 8.3s, Background: true
🧪 AudioRepositoryImpl: Test 10s - Recording: true, Time: 10.1s, Background: true
🎵 BackgroundAudioService: Recording stopped
```

### Key Features Tested:

1. **Background Task Management**
   - Automatic `beginBackgroundTask()` when recording starts
   - Proper `endBackgroundTask()` when recording ends
   - Background task expiration handling

2. **Audio Session Configuration**
   - `.playAndRecord` category with `.defaultToSpeaker` option
   - Maintains session during background operation
   - Handles audio interruptions gracefully

3. **Single Recorder Instance**
   - Only one AVAudioRecorder active at a time
   - Proper cleanup and resource management
   - Thread-safe operations

4. **State Management**
   - Real-time state updates via Combine
   - Proper @Published property updates
   - Error state handling

### Debug Information:
Use `audioRepo.debugInfo` to get comprehensive state information:
```swift
print(audioRepo.debugInfo)
```

This will show current playback state, recording state, permissions, and background task status.

### Next Steps:
After confirming background recording works, you can:
1. Integrate with existing `AudioRecorder` replacement
2. Update the DI container to use the enhanced AudioRepositoryImpl
3. Add Live Activity integration for recording status
4. Implement proper error handling in the UI layer
