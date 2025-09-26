# Sonora: Micro-Interactions & Interface Delight
*The Art of Making Intelligence Feel Magical*

> Micro-interactions are the difference between a functional app and a beloved one. This document defines the specific design details that make Sonora feel alive, responsive, and delightful to use.

---

## Principles of Sonora Micro-Interactions

### 1. **Purposeful, Not Decorative**
**Philosophy**: Every animation, vibration, and transition serves user understanding or emotional connection.

**Examples**:
- ✅ Sonic Bloom expands to show recording is active and energy is flowing
- ✅ Haptic feedback confirms successful voice capture
- ✅ Loading animations build anticipation for meaningful results
- ❌ Decorative animations that don't enhance comprehension
- ❌ Effects that slow down interaction without purpose

### 2. **Responsive, Not Delayed**
**Philosophy**: Interface should respond immediately to user input, with intelligence happening asynchronously.

**Implementation**:
- Recording button responds instantly (0ms delay)
- Visual feedback appears before AI processing begins
- Progressive enhancement as processing completes
- Never block user interaction waiting for AI

### 3. **Natural, Not Mechanical**
**Philosophy**: Animations follow physics and human movement patterns, not robotic timing.

**Technical Approach**:
- Spring animations over linear easing
- Variable timing based on content and context
- Stagger effects for multiple elements
- Respects system accessibility settings

### 4. **Contextually Aware**
**Philosophy**: Interactions adapt to emotional state, content type, and user patterns.

**Adaptive Behavior**:
- Calmer animations during stress or reflection
- More energetic feedback for exciting discoveries
- Reduced motion for accessibility preferences
- Cultural and personal preference sensitivity

---

## Haptic Feedback Architecture

### Core Haptic Vocabulary

#### **1. Recording Lifecycle**
```swift
// Recording Start
HapticManager.shared.playRecordingStart()
// Implementation: Light impact + subtle notification
// Feel: Gentle "begin" sensation

// Recording Stop
HapticManager.shared.playRecordingStop()
// Implementation: Medium impact + success notification
// Feel: Satisfying "completion" sensation

// Recording Error
HapticManager.shared.playError()
// Implementation: Heavy impact + error notification
// Feel: Clear "something went wrong" without alarm
```

#### **2. Discovery & Insights**
```swift
// First Insight Discovered
HapticManager.shared.playInsightDiscovered()
// Implementation: Light impact + gentle notification sequence
// Feel: "Aha moment" surprise and delight

// Pattern Connection
HapticManager.shared.playConnectionFound()
// Implementation: Two light impacts with 100ms gap
// Feel: "Things clicking together"

// Significant Breakthrough
HapticManager.shared.playBreakthrough()
// Implementation: Medium impact + success + light follow-up
// Feel: Major "wow" moment without overwhelm
```

#### **3. Navigation & Confirmation**
```swift
// Selection/Tap
HapticManager.shared.playSelection()
// Implementation: Light impact
// Feel: Crisp, immediate confirmation

// Page Turn/Transition
HapticManager.shared.playTransition()
// Implementation: Subtle light impact
// Feel: Gentle movement acknowledgment

// Deep Press/Secondary Action
HapticManager.shared.playSecondaryAction()
// Implementation: Medium impact
// Feel: "Deeper" interaction distinguished from tap
```

### Haptic Timing & Coordination

#### **Synchronized with Visual**
```swift
// Always pair haptics with visual feedback
Button("Record") {
    withAnimation(.spring(response: 0.3)) {
        isRecording = true
        // Haptic triggers at same moment as visual expansion
        HapticManager.shared.playRecordingStart()
    }
}
```

#### **Contextual Intensity**
```swift
// Adapt intensity to context
func playContextualSuccess(importance: InsightImportance) {
    switch importance {
    case .minor:
        HapticManager.shared.playSubtle()
    case .significant:
        HapticManager.shared.playInsightDiscovered()
    case .breakthrough:
        HapticManager.shared.playBreakthrough()
    }
}
```

---

## Animation System

### Spring Physics Constants
**Based on iOS Human Interface Guidelines and natural motion**

```swift
// Standard Sonora Springs
struct SonoraSpring {
    // Quick Response (UI feedback)
    static let quick = Spring(response: 0.3, dampingFraction: 0.8)

    // Standard Response (most interactions)
    static let standard = Spring(response: 0.5, dampingFraction: 0.75)

    // Gentle Response (content transitions)
    static let gentle = Spring(response: 0.7, dampingFraction: 0.85)

    // Dramatic Response (major state changes)
    static let dramatic = Spring(response: 0.4, dampingFraction: 0.6)
}
```

### Core Animation Patterns

#### **1. Sonic Bloom (Recording Button)**
**Purpose**: Communicate recording state and energy flow

```swift
struct SonicBloomAnimation: View {
    @State private var isRecording: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Outer expanding ring
            Circle()
                .stroke(Color.blue, lineWidth: 2)
                .scaleEffect(isRecording ? 2.0 : 1.0)
                .opacity(isRecording ? 0.0 : 0.3)
                .animation(.easeOut(duration: 1.5), value: isRecording)

            // Main button with gentle pulse
            Circle()
                .fill(Color.blue)
                .scaleEffect(pulseScale)
                .onReceive(Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()) { _ in
                    if isRecording {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                            pulseScale = pulseScale == 1.0 ? 1.05 : 1.0
                        }
                    }
                }
        }
    }
}
```

#### **2. Insight Card Reveal**
**Purpose**: Progressive disclosure of AI analysis results

```swift
struct InsightCardReveal: View {
    @State private var cards: [InsightCard] = []
    @State private var visibleCards: Set<UUID> = []

    func revealCards() {
        for (index, card) in cards.enumerated() {
            withAnimation(
                .spring(response: 0.6, dampingFraction: 0.8)
                .delay(Double(index) * 0.15)
            ) {
                visibleCards.insert(card.id)
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(cards) { card in
                InsightCardView(card: card)
                    .scaleEffect(visibleCards.contains(card.id) ? 1.0 : 0.8)
                    .opacity(visibleCards.contains(card.id) ? 1.0 : 0.0)
                    .offset(y: visibleCards.contains(card.id) ? 0 : 20)
            }
        }
    }
}
```

#### **3. Text Stream Animation**
**Purpose**: Show transcription happening in real-time

```swift
struct StreamingText: View {
    @State private var displayedText: String = ""
    @State private var cursorVisible: Bool = true

    func streamText(_ fullText: String) {
        displayedText = ""

        for (index, character) in fullText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.03) {
                displayedText.append(character)

                // Add natural pauses at punctuation
                if ".,!?".contains(character) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Slight pause for natural rhythm
                    }
                }
            }
        }
    }

    var body: some View {
        HStack {
            Text(displayedText)
                .font(.system(.body, design: .serif))

            // Blinking cursor during typing
            Rectangle()
                .fill(Color.blue)
                .frame(width: 2, height: 20)
                .opacity(cursorVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: cursorVisible)
                .onAppear { cursorVisible.toggle() }
        }
    }
}
```

### Stagger Effects for Collections

#### **List Item Reveals**
```swift
struct StaggeredList: View {
    @State private var visibleItems: Set<Int> = []

    func animateIn() {
        for index in items.indices {
            withAnimation(
                .spring(response: 0.5, dampingFraction: 0.8)
                .delay(Double(index) * 0.1)
            ) {
                visibleItems.insert(index)
            }
        }
    }
}
```

#### **Insight Tag Clouds**
```swift
struct TagCloudAnimation: View {
    func animateTags() {
        for (index, tag) in tags.enumerated() {
            let randomDelay = Double.random(in: 0...0.5)
            withAnimation(
                .spring(response: 0.6, dampingFraction: 0.7)
                .delay(randomDelay)
            ) {
                tag.isVisible = true
            }
        }
    }
}
```

---

## Sound Design (Optional Audio Feedback)

### Audio Feedback Philosophy
**Principle**: Sound should enhance, never distract or annoy

### Core Sound Events

#### **1. Recording Sounds**
```swift
// Recording Start: Subtle "begin" tone
SoundManager.shared.playRecordingStart()
// File: recording_start.aiff (200ms, 800Hz gentle tone)

// Recording Stop: Satisfying "complete" tone
SoundManager.shared.playRecordingStop()
// File: recording_stop.aiff (300ms, 600Hz with fade)
```

#### **2. Discovery Sounds**
```swift
// Insight Discovery: Gentle "aha" chime
SoundManager.shared.playInsightChime()
// File: insight_chime.aiff (400ms, harmonic bell)

// Connection Found: Two-note harmony
SoundManager.shared.playConnectionTone()
// File: connection_tone.aiff (500ms, major third interval)
```

#### **3. System Integration**
```swift
// Respect system settings
if SoundManager.shared.systemSoundsEnabled {
    playAudioFeedback()
} else {
    // Fall back to haptics only
    playHapticFeedback()
}

// Honor Do Not Disturb mode
if SoundManager.shared.isDNDActive {
    suppressAllAudio()
}
```

### Audio Implementation Guidelines

#### **Volume & Frequency**
- Maximum volume: 40% of system maximum
- Frequency range: 400-1200Hz (pleasant, non-intrusive)
- Duration: Never longer than 500ms
- Fade-in/fade-out: Always smooth transitions

#### **User Control**
- Global sound toggle in settings
- Independent from system volume
- No sound during Silent mode
- Accessibility compatibility

---

## Visual Feedback Patterns

### State Change Indicators

#### **1. Processing States**
```swift
struct ProcessingIndicator: View {
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer ring with rotation
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                .frame(width: 24, height: 24)

            // Inner pulsing dot
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .scaleEffect(scale)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: scale
                )
        }
        .rotationEffect(.degrees(rotationAngle))
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            scale = 1.2
        }
    }
}
```

#### **2. Success Confirmations**
```swift
struct SuccessCheckmark: View {
    @State private var progress: CGFloat = 0.0

    var body: some View {
        Path { path in
            // Draw checkmark path
            path.move(to: CGPoint(x: 8, y: 16))
            path.addLine(to: CGPoint(x: 12, y: 20))
            path.addLine(to: CGPoint(x: 20, y: 8))
        }
        .trim(from: 0, to: progress)
        .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
        .onAppear {
            progress = 1.0
        }
    }
}
```

### Content Loading Patterns

#### **Skeleton Screens**
```swift
struct SkeletonLoader: View {
    @State private var isAnimating: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 20)
                .frame(maxWidth: .infinity)

            // Content skeletons
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .frame(width: CGFloat.random(in: 0.6...0.9) * 300)
            }
        }
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear { isAnimating = true }
    }
}
```

---

## Timing & Pacing Guidelines

### Response Time Expectations

#### **Immediate Response (0-100ms)**
- Button press acknowledgment
- Touch down feedback
- Visual state changes
- Navigation gestures

#### **Quick Response (100-300ms)**
- Recording start/stop
- Simple UI transitions
- Haptic feedback coordination
- Audio feedback triggers

#### **Acceptable Response (300ms-1s)**
- Transcription display
- Simple AI analysis
- Page transitions
- Network requests (with loading indicators)

#### **Patient Response (1-3s)**
- Complex AI analysis
- Insight generation
- Pattern recognition
- Historical data processing

#### **Extended Response (3s+)**
- Deep analysis features
- Large data exports
- Model training/adaptation
- Batch processing operations

### Progressive Enhancement Strategy

#### **Layered Response Pattern**
```swift
func handleRecordingProcessing() {
    // Immediate (0ms): Visual feedback
    showRecordingComplete()
    HapticManager.shared.playRecordingStop()

    // Quick (100ms): Show transcription loading
    showTranscriptionLoader()

    // Acceptable (500ms): Display transcription
    Task {
        let transcription = await processAudio()
        showTranscription(transcription)

        // Patient (2s): Show analysis loading
        showAnalysisLoader()

        let insights = await analyzeContent(transcription)
        showInsights(insights)
    }
}
```

---

## Accessibility & Reduced Motion

### Motion Sensitivity Support

#### **Reduced Motion Compliance**
```swift
func animateWithRespectForAccessibility<T: Equatable>(
    _ value: T,
    animation: Animation = .spring()
) -> Animation? {
    if UIAccessibility.isReduceMotionEnabled {
        return .linear(duration: 0.1) // Minimal transition
    } else {
        return animation // Full animation
    }
}
```

#### **Alternative Feedback Modes**
```swift
struct AccessibleFeedback {
    static func provideStateChange(from oldState: State, to newState: State) {
        if UIAccessibility.isReduceMotionEnabled {
            // Use color changes and haptics instead of animations
            provideColorFeedback(for: newState)
            provideHapticFeedback(for: newState)
        } else {
            // Full animation with visual effects
            provideAnimatedTransition(from: oldState, to: newState)
        }
    }
}
```

### VoiceOver Integration

#### **Animation Announcements**
```swift
func announceStateChange(_ message: String) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        // Delay to let animation complete
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// Usage
withAnimation(.spring()) {
    isProcessing = true
    announceStateChange("Processing your recording")
}
```

---

## Implementation Checklist

### Development Guidelines

#### **Performance Requirements**
- [ ] All animations maintain 60fps on target devices
- [ ] Haptic feedback triggers within 16ms of touch
- [ ] Visual feedback appears within 100ms of user action
- [ ] Reduced motion alternatives implemented
- [ ] Memory usage optimized for animation objects

#### **Quality Assurance**
- [ ] Test with accessibility settings enabled
- [ ] Verify haptics on multiple device types
- [ ] Confirm animations work in dark mode
- [ ] Test with various system font sizes
- [ ] Validate behavior during low battery mode

#### **User Testing Focus**
- [ ] First impression (initial delight)
- [ ] Sustained use (animations don't become annoying)
- [ ] Error recovery (graceful failure states)
- [ ] Accessibility experience (equal delight for all users)
- [ ] Cross-cultural sensitivity (motion and sound preferences)

---

*"The magic is not in the complexity of the animation, but in the perfect timing of the simplest gesture. Every micro-interaction should feel like Sonora is paying attention to exactly what the user needs in that moment."*