import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct SonoraLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SonoraLiveActivityAttributes.self) { context in
            // Lock Screen and Notification display
            PremiumLiveActivityView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(Color.semantic(.textPrimary))
                .widgetURL(URL(string: "sonora://open"))

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.isCountdown ? "hourglass.circle.fill" : "mic.fill")
                            .font(.title3)
                            .foregroundStyle(Color.semantic(.fillSecondary))
                            .symbolEffect(.pulse, options: .repeating, value: !context.state.isCountdown)
                        Text("SONORA")
                            .font(.caption.smallCaps())
                            .foregroundStyle(Color.semantic(.textSecondary))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: StopRecordingIntent()) {
                        Text("Stop")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.semantic(.textOnColored))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.semantic(.fillSecondary)))
                    }
                    .buttonStyle(.plain)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandBottomContent(context: context)
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.semantic(.fillSecondary))
                    .symbolEffect(.pulse, options: .repeating, value: true)
            } compactTrailing: {
                Text(shortElapsed(from: context.state.startTime))
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.semantic(.fillSecondary))
            }
            .widgetURL(URL(string: "sonora://open"))
        }
    }
}

// MARK: - Premium Live Activity View (Lock Screen / Notification)
struct PremiumLiveActivityView: View {
    let context: ActivityViewContext<SonoraLiveActivityAttributes>
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.semantic(.fillSecondary))
                    .frame(width: 36, height: 36)
                Image(systemName: context.state.isCountdown ? "hourglass" : "mic.fill")
                    .foregroundStyle(Color.semantic(.textOnColored))
                    .symbolEffect(.pulse, options: .repeating, value: !context.state.isCountdown)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SONORA")
                    .font(.caption.smallCaps())
                    .foregroundStyle(Color.semantic(.textSecondary))

                HStack(spacing: 10) {
                    Group {
                        if context.state.isCountdown, let rem = context.state.remainingTime {
                            Text(countdownString(rem))
                        } else {
                            Text(context.state.startTime, style: .timer)
                        }
                    }
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(Color.semantic(.textPrimary))
                    .contentTransition(.numericText())

                    if context.state.level != nil {
                        VoiceResonanceWaveform(
                            context: context,
                            maxHeight: 32,
                            isLuminanceReduced: isLuminanceReduced,
                            colorScheme: colorScheme
                        )
                    }
                }
            }

            Spacer(minLength: 0)

            Button(intent: StopRecordingIntent()) {
                Text("Stop")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.semantic(.textOnColored))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.semantic(.fillSecondary)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.semantic(.separator), lineWidth: 0.5))
        )
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            // Softer, darker gradient for OLED
            return [Color.semantic(.bgSecondary), Color.semantic(.bgPrimary)]
        } else {
            // Light, airy gradient aligning with brand
            return [Color(hex: 0xE8F0FF).opacity(0.9), Color.white]
        }
    }
}

// MARK: - Waveform Components

/// Dynamic Island bottom content with enhanced waveform
struct DynamicIslandBottomContent: View {
    let context: ActivityViewContext<SonoraLiveActivityAttributes>
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Text(context.state.isCountdown && context.state.remainingTime != nil ?
                 countdownString(context.state.remainingTime ?? 0) :
                 elapsedString(from: context.state.startTime))
            .font(.system(.body, design: .serif).weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Color.semantic(.textPrimary))

            Spacer(minLength: 0)

            if context.state.level != nil {
                VoiceResonanceWaveform(
                    context: context,
                    maxHeight: 24,
                    isLuminanceReduced: isLuminanceReduced,
                    colorScheme: colorScheme
                )
            }
        }
        .padding(.horizontal, 8)
    }
}

/// Reusable voice-centric waveform visualization
struct VoiceResonanceWaveform: View {
    let context: ActivityViewContext<SonoraLiveActivityAttributes>
    let maxHeight: CGFloat
    let isLuminanceReduced: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            let bars = voiceResonanceBarHeights(
                context: context,
                maxHeight: maxHeight,
                isLuminanceReduced: isLuminanceReduced
            )
            ForEach(0..<bars.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(index: i))
                    .frame(width: 3, height: bars[i])
            }
        }
        .frame(height: maxHeight + 4)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: context.state.level ?? 0)
        .animation(.easeInOut(duration: 0.25), value: context.state.duration)
    }

    private func barColor(index: Int) -> Color {
        let baseOpacity: Double = isLuminanceReduced ? 0.5 : (colorScheme == .dark ? 1.0 : 0.95)

        // Subtle center emphasis (index 4 is center for 9-bar layout)
        let isCenterBar = (index == 4 || index == 2) // Center region
        let opacity = isCenterBar ? min(1.0, baseOpacity + 0.05) : baseOpacity

        return Color.semantic(.textPrimary).opacity(opacity)
    }
}

// MARK: - Helper Functions

// Helper functions remain the same
private func elapsedString(from start: Date) -> String {
    let interval = max(0, Int(Date().timeIntervalSince(start)))
    return String(format: "%d:%02d", interval / 60, interval % 60)
}
private func shortElapsed(from start: Date) -> String { elapsedString(from: start) }
private func countdownString(_ remaining: TimeInterval) -> String {
    let t = max(0, Int(remaining))
    return String(format: "%d:%02d", t / 60, t % 60)
}

// MARK: - Voice-Centric Waveform Visualization
// Enhanced waveform algorithm that reflects vocal frequency characteristics
// Inspired by Sonora's "Sonic Bloom" organic design philosophy

/// Voice-optimized waveform with organic breathing motion
/// - Parameters:
///   - context: Activity context with audio state
///   - maxHeight: Maximum bar height in points
///   - isLuminanceReduced: True when Always-On Display is active
/// - Returns: Array of 9 bar heights (CGFloat)
private func voiceResonanceBarHeights(
    context: ActivityViewContext<SonoraLiveActivityAttributes>,
    maxHeight: CGFloat,
    isLuminanceReduced: Bool
) -> [CGFloat] {
    // Always-On Display: Simplified 5-bar visualization (30-40% battery savings)
    if isLuminanceReduced {
        return simplifiedAODBarHeights(level: context.state.level ?? 0, maxHeight: maxHeight)
    }

    // Full display: Rich 9-bar voice-centric visualization
    let level = context.state.level ?? 0
    let t = context.state.duration

    // 9-bar symmetrical vocal spectrum layout
    // Indices:     0    1    2    3    4    5    6    7    8
    // Role:       Hi   Mid  Mid  Low  CTR  Low  Mid  Mid  Hi
    // Heights:    0.4  0.6  0.8  0.95 1.0  0.95 0.8  0.6  0.4
    let multipliers: [CGFloat] = [0.4, 0.6, 0.8, 0.95, 1.0, 0.95, 0.8, 0.6, 0.4]

    let minHeight: CGFloat = 4
    let range = maxHeight - minHeight

    // Detect speech pause (sustained low level)
    let isPause = level < 0.15
    let pauseDamping: CGFloat = isPause ? 0.6 : 1.0

    // Organic breathing phase (3.3s cycle - natural breathing rate)
    let breathingFreq = 0.3 // Hz
    let breathingPhaseSpeed = breathingFreq * 2.0 * .pi

    return multipliers.enumerated().map { index, m in
        // Phase offset creates left→center→right flowing wave
        let phaseOffset = Double(index - 4) * 0.35 // center bar (index 4) at zero offset
        let breathingPhase = t * breathingPhaseSpeed + phaseOffset

        // Organic variation envelope (±15% around center)
        let breathingVariation = 0.85 + 0.15 * sin(breathingPhase)

        // Speech rhythm: higher frequency ripple during active speech
        let speechRipple: CGFloat = isPause ? 1.0 : (1.0 + 0.08 * sin(t * 4.0 + phaseOffset))

        // Combine all layers
        let barLevel = max(0.0, min(1.0, level * breathingVariation * speechRipple * pauseDamping))
        let height = minHeight + range * CGFloat(barLevel) * m

        return max(minHeight, min(maxHeight, height))
    }
}

/// Simplified waveform for Always-On Display (reduces battery consumption)
/// - Parameters:
///   - level: Audio level (0.0 to 1.0)
///   - maxHeight: Maximum bar height
/// - Returns: Array of 5 bar heights (static, no animation)
private func simplifiedAODBarHeights(level: Double, maxHeight: CGFloat) -> [CGFloat] {
    let l = max(0.0, min(1.0, level))
    // Simplified 5-bar layout for AOD
    let multipliers: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]
    let minHeight: CGFloat = 3 // Slightly lower minimum for AOD

    return multipliers.map { m in
        let height = minHeight + (maxHeight - minHeight) * CGFloat(l) * m
        return max(minHeight, height)
    }
}

// MARK: - Backward Compatible Function (for migration)
/// Legacy waveform function (7 bars) - kept for backward compatibility
/// Use voiceResonanceBarHeights() for new implementations
private func expressiveBarHeights(level: Double, t: Double, maxHeight: CGFloat) -> [CGFloat] {
    let l = max(0.0, min(1.0, level))
    let multipliers: [CGFloat] = [0.3, 0.6, 0.9, 1.0, 0.85, 0.7, 0.4]
    let minHeight: CGFloat = 4
    let range: CGFloat = maxHeight - minHeight

    return multipliers.enumerated().map { index, m in
        let phase = Double(index) * 0.7 + t * 2.2
        let envelope = 1.0 + 0.3 * sin(phase)
        let barLevel = max(0.0, min(1.0, l * envelope))
        let height = minHeight + range * CGFloat(barLevel) * m
        return max(minHeight, min(maxHeight, height))
    }
}
