import ActivityKit
import WidgetKit
import SwiftUI

struct SonoraLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SonoraLiveActivityAttributes.self) { context in
            // Lock Screen and Notification Display - Larger, more prominent
            VStack(alignment: .leading, spacing: 12) {
                // Header row with recording indicator and stop button
                HStack(alignment: .center, spacing: 16) {
                    // Recording indicator with animation
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: context.state.isCountdown ? "hourglass.circle.fill" : "mic.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse, options: .repeating, value: !context.state.isCountdown)
                            .frame(width: 28, height: 28)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(context.state.memoTitle)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Text(context.state.isCountdown ? "Auto-stop countdown" : "Live")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Open the host app via deep link to stop recording
                    if let url = URL(string: "sonora://stopRecording") {
                        Link(destination: url) {
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Stop")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.red.gradient)
                                    .shadow(color: .red.opacity(0.4), radius: 4, x: 0, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
                
                // Large monospace timer display
                HStack(alignment: .center, spacing: 8) {
                    // Recording pulse indicator
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(context.state.isCountdown ? 0.0 : 0.9)
                        .animation(.easeInOut(duration: 1.0).repeatForever(), value: !context.state.isCountdown)
                    
                    // Large monospace timer
                    Text(timerString(from: context.state.startTime, isCountdown: context.state.isCountdown, remaining: context.state.remainingTime))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(1.0)
                    
                    Spacer()
                    
                    // Mini waveform animation
                    HStack(alignment: .center, spacing: 3) {
                        ForEach(0..<5, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.7))
                                .frame(width: 4, height: CGFloat.random(in: 8...16))
                                .animation(
                                    .easeInOut(duration: 0.8)
                                    .repeatForever()
                                    .delay(Double(index) * 0.15),
                                    value: !context.state.isCountdown
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.35, blue: 0.85),
                                Color(red: 0.05, green: 0.25, blue: 0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view - full recording interface
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 6) {
                            Image(systemName: context.state.isCountdown ? "hourglass.circle.fill" : "mic.circle.fill")
                                .font(.title2)
                                .foregroundStyle(context.state.isCountdown ? .orange : .red)
                                .symbolEffect(.pulse, options: .repeating, value: !context.state.isCountdown)
                            
                            Text("Recording")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if context.state.isCountdown, let rem = context.state.remainingTime {
                            HStack(alignment: .center, spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text(countdownString(rem))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }
                        } else {
                            HStack(alignment: .center, spacing: 4) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 6, height: 6)
                                    .opacity(0.8)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(), value: true)
                                
                                Text(elapsedString(from: context.state.startTime))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.memoTitle)
                                .font(.footnote)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.primary)
                            
                            if context.state.isCountdown {
                                Text("Auto-stop countdown")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Tap to stop recording")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Waveform-like animation
                        HStack(alignment: .center, spacing: 2) {
                            ForEach(0..<4, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(.blue.gradient)
                                    .frame(width: 3, height: CGFloat.random(in: 4...12))
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.1),
                                        value: true
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                
            } compactLeading: {
                // Compact leading - just the icon with animation
                Image(systemName: context.state.isCountdown ? "hourglass.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(context.state.isCountdown ? .orange : .red)
                    .symbolEffect(.pulse, options: .repeating, value: !context.state.isCountdown)
                    
            } compactTrailing: {
                // Compact trailing - timer with visual indicator
                HStack(alignment: .center, spacing: 3) {
                    if !context.state.isCountdown {
                        Circle()
                            .fill(.red)
                            .frame(width: 4, height: 4)
                            .opacity(0.8)
                    }
                    
                    if context.state.isCountdown, let rem = context.state.remainingTime {
                        Text(shortCountdown(rem))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                    } else {
                        Text(shortElapsed(from: context.state.startTime))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                }
                
            } minimal: {
                // Minimal view - animated recording indicator
                Image(systemName: "mic.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating, value: true)
            }
            // Use App Intent for Dynamic Island tap (iOS 17+) or fallback to URL
            .widgetURL(URL(string: "sonora://stopRecording"))
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
