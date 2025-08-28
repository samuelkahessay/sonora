//
//  SonoraLiveActivityLiveActivity.swift
//  SonoraLiveActivity
//
//  Created by Samuel Kahessay on 2025-08-27.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SonoraLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SonoraLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(context.state.emoji)
                    Text(context.state.memoTitle)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    // Deep link to stop recording in the app
                    if let url = URL(string: "sonora://stopRecording") {
                        Link(destination: url) {
                            Text("Stop")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .tint(.red)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
                Text(timerString(from: context.state.startTime, isCountdown: context.state.isCountdown, remaining: context.state.remainingTime))
                    .font(.caption).monospacedDigit()
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .activityBackgroundTint(Color.cyan.opacity(0.2))
            .activitySystemActionForegroundColor(Color.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.emoji)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isCountdown, let rem = context.state.remainingTime {
                        Text(countdownString(rem)).monospacedDigit()
                    } else {
                        Text(elapsedString(from: context.state.startTime)).monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.memoTitle)
                        .font(.footnote)
                        .lineLimit(1)
                }
            } compactLeading: {
                Text(context.state.emoji)
            } compactTrailing: {
                if context.state.isCountdown, let rem = context.state.remainingTime {
                    Text(shortCountdown(rem)).monospacedDigit()
                } else {
                    Text(shortElapsed(from: context.state.startTime)).monospacedDigit()
                }
            } minimal: {
                Text(context.state.emoji)
            }
        }
    }
}

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
    return "Recording " + elapsedString(from: start)
}

// Previews omitted for simplicity
