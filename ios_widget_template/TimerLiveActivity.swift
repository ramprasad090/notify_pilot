// TimerLiveActivity.swift
// Example Live Activity for countdown timers.
// Copy into your Widget Extension target and customize.

import ActivityKit
import SwiftUI
import WidgetKit

struct TimerLiveActivity: Widget {
    let sharedDefaults = UserDefaults(suiteName: "group.YOUR_APP_GROUP_ID")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GenericLiveActivityAttributes.self) { context in
            if context.attributes.type == "timer" {
                timerLockScreen(context: context)
            }
        } dynamicIsland: { context in
            if context.attributes.type == "timer" {
                timerDynamicIsland(context: context)
            } else {
                DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) { EmptyView() }
                    DynamicIslandExpandedRegion(.trailing) { EmptyView() }
                } compactLeading: {
                    EmptyView()
                } compactTrailing: {
                    EmptyView()
                } minimal: {
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    func timerLockScreen(context: ActivityViewContext<GenericLiveActivityAttributes>) -> some View {
        let label = sharedDefaults.string(forKey: "attr_label") ?? "Timer"
        let endTimeStr = context.state.data["endTime"]?.stringValue ?? ""
        let isPaused = context.state.data["isPaused"]?.boolValue ?? false

        let endDate = ISO8601DateFormatter().date(from: endTimeStr) ?? Date()

        VStack(spacing: 8) {
            Text(label)
                .font(.headline)
                .foregroundColor(.white)

            if isPaused {
                Text("PAUSED")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            } else {
                Text(endDate, style: .timer)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
    }

    func timerDynamicIsland(context: ActivityViewContext<GenericLiveActivityAttributes>) -> DynamicIsland {
        let endTimeStr = context.state.data["endTime"]?.stringValue ?? ""
        let isPaused = context.state.data["isPaused"]?.boolValue ?? false
        let endDate = ISO8601DateFormatter().date(from: endTimeStr) ?? Date()

        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                Label(sharedDefaults.string(forKey: "attr_label") ?? "Timer",
                      systemImage: "timer")
                    .font(.caption)
            }
            DynamicIslandExpandedRegion(.trailing) {
                if isPaused {
                    Text("PAUSED")
                        .font(.caption)
                        .foregroundColor(.yellow)
                } else {
                    Text(endDate, style: .timer)
                        .font(.title3)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }
        } compactLeading: {
            Image(systemName: "timer")
                .foregroundColor(.cyan)
        } compactTrailing: {
            if isPaused {
                Image(systemName: "pause.fill")
                    .foregroundColor(.yellow)
            } else {
                Text(endDate, style: .timer)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.cyan)
            }
        } minimal: {
            Image(systemName: "timer")
                .foregroundColor(.cyan)
        }
    }
}
