// SportsScoreLiveActivity.swift
// Example Live Activity for live sports scores (cricket/football).
// Copy into your Widget Extension target and customize.

import ActivityKit
import SwiftUI
import WidgetKit

struct SportsScoreLiveActivity: Widget {
    let sharedDefaults = UserDefaults(suiteName: "group.YOUR_APP_GROUP_ID")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GenericLiveActivityAttributes.self) { context in
            if context.attributes.type == "sports_score" {
                sportsLockScreen(context: context)
            }
        } dynamicIsland: { context in
            if context.attributes.type == "sports_score" {
                sportsDynamicIsland(context: context)
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
    func sportsLockScreen(context: ActivityViewContext<GenericLiveActivityAttributes>) -> some View {
        let homeTeam = sharedDefaults.string(forKey: "attr_homeTeam") ?? "Home"
        let awayTeam = sharedDefaults.string(forKey: "attr_awayTeam") ?? "Away"
        let homeScore = context.state.data["homeScore"]?.stringValue ?? "0"
        let awayScore = context.state.data["awayScore"]?.stringValue ?? "0"
        let overs = context.state.data["overs"]?.stringValue
        let status = context.state.data["status"]?.stringValue ?? "live"

        HStack {
            // Home team
            VStack(spacing: 4) {
                Text(homeTeam)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(homeScore)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Spacer()

            // Match info
            VStack(spacing: 2) {
                Text(status.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(status == "live" ? .red : .gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        status == "live"
                            ? Color.red.opacity(0.2)
                            : Color.gray.opacity(0.2)
                    )
                    .cornerRadius(4)

                if let overs = overs {
                    Text("Ov \(overs)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Away team
            VStack(spacing: 4) {
                Text(awayTeam)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(awayScore)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
    }

    func sportsDynamicIsland(context: ActivityViewContext<GenericLiveActivityAttributes>) -> DynamicIsland {
        let homeTeam = sharedDefaults.string(forKey: "attr_homeTeam") ?? "HOM"
        let awayTeam = sharedDefaults.string(forKey: "attr_awayTeam") ?? "AWY"
        let homeScore = context.state.data["homeScore"]?.stringValue ?? "0"
        let awayScore = context.state.data["awayScore"]?.stringValue ?? "0"

        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                VStack {
                    Text(homeTeam).font(.caption).fontWeight(.bold)
                    Text(homeScore).font(.title3).fontWeight(.bold)
                }
            }
            DynamicIslandExpandedRegion(.trailing) {
                VStack {
                    Text(awayTeam).font(.caption).fontWeight(.bold)
                    Text(awayScore).font(.title3).fontWeight(.bold)
                }
            }
            DynamicIslandExpandedRegion(.center) {
                Text("VS")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        } compactLeading: {
            Text("\(homeTeam) \(homeScore)")
                .font(.caption2)
                .fontWeight(.bold)
        } compactTrailing: {
            Text("\(awayTeam) \(awayScore)")
                .font(.caption2)
                .fontWeight(.bold)
        } minimal: {
            Image(systemName: "sportscourt.fill")
                .foregroundColor(.red)
        }
    }
}
