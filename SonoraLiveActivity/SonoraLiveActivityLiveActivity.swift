import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

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
                            .foregroundStyle(Color.semantic(.brandPrimary))
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
                            .background(Capsule().fill(Color.semantic(.brandSecondary)))
                    }
                    .buttonStyle(.plain)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        Text(context.state.isCountdown && context.state.remainingTime != nil ?
                             countdownString(context.state.remainingTime!) :
                             elapsedString(from: context.state.startTime))
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.semantic(.textPrimary))

                        Spacer(minLength: 0)

                        if let lvl = context.state.level {
                            HStack(alignment: .bottom, spacing: 3) {
                                let bars = barHeights(level: lvl)
                                ForEach(0..<bars.count, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.semantic(.textSecondary).opacity(0.9))
                                        .frame(width: 3, height: bars[i])
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.semantic(.brandPrimary))
                    .symbolEffect(.pulse, options: .repeating, value: true)
            } compactTrailing: {
                Text(shortElapsed(from: context.state.startTime))
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.semantic(.brandPrimary))
            }
            .widgetURL(URL(string: "sonora://open"))
        }
    }
}

// MARK: - Premium Live Activity View (Lock Screen / Notification)
struct PremiumLiveActivityView: View {
    let context: ActivityViewContext<SonoraLiveActivityAttributes>
    @Environment(\.colorScheme) private var colorScheme

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

                    if let lvl = context.state.level {
                        HStack(alignment: .bottom, spacing: 3) {
                            let bars = barHeights(level: lvl)
                            ForEach(0..<bars.count, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.semantic(.textSecondary).opacity(0.9))
                                    .frame(width: 3, height: bars[i])
                            }
                        }
                        .transition(.opacity)
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
                    .background(Capsule().fill(Color.semantic(.brandSecondary)))
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

// Helper functions remain the same
private func elapsedString(from start: Date) -> String {
    let interval = max(0, Int(Date().timeIntervalSince(start)))
    return String(format: "%d:%02d", interval/60, interval%60)
}
private func shortElapsed(from start: Date) -> String { elapsedString(from: start) }
private func countdownString(_ remaining: TimeInterval) -> String {
    let t = max(0, Int(remaining))
    return String(format: "%d:%02d", t/60, t%60)
}
private func shortCountdown(_ remaining: TimeInterval) -> String { countdownString(remaining) }
private func timerString(from start: Date, isCountdown: Bool, remaining: TimeInterval?) -> String {
    if isCountdown, let rem = remaining { return "Ends in " + countdownString(rem) }
    return elapsedString(from: start)
}

// Deterministic mini-waveform bar heights (no random). Level: 0..1
private func barHeights(level: Double) -> [CGFloat] {
    let l = max(0.0, min(1.0, level))
    let multipliers: [CGFloat] = [0.6, 0.8, 1.0, 0.8, 0.6]
    let minHeight: CGFloat = 6
    let range: CGFloat = 12 // so 6..18 px
    return multipliers.map { m in minHeight + range * CGFloat(l) * m }
}
