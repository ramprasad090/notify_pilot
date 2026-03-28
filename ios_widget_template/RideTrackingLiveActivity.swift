// RideTrackingLiveActivity.swift
// Example Live Activity for ride-hailing apps (Ola/Uber style).
// Copy into your Widget Extension target and customize.

import ActivityKit
import SwiftUI
import WidgetKit

struct RideTrackingLiveActivity: Widget {
    // IMPORTANT: Replace with your App Group ID
    let sharedDefaults = UserDefaults(suiteName: "group.YOUR_APP_GROUP_ID")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GenericLiveActivityAttributes.self) { context in
            // Only handle ride_tracking type
            if context.attributes.type == "ride_tracking" {
                rideTrackingLockScreen(context: context)
            }
        } dynamicIsland: { context in
            if context.attributes.type == "ride_tracking" {
                rideTrackingDynamicIsland(context: context)
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

    // MARK: - Lock Screen UI

    @ViewBuilder
    func rideTrackingLockScreen(context: ActivityViewContext<GenericLiveActivityAttributes>) -> some View {
        let eta = context.state.data["eta"]?.stringValue ?? "--"
        let driver = sharedDefaults.string(forKey: "attr_driverName") ?? "Driver"
        let vehicle = sharedDefaults.string(forKey: "attr_vehicleNumber") ?? ""
        let status = context.state.data["status"]?.stringValue ?? "en route"
        let progress = context.state.data["progress"]?.doubleValue ?? 0

        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(driver)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(vehicle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(eta)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("ETA")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            ProgressView(value: progress)
                .tint(.green)

            Text(status.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
    }

    // MARK: - Dynamic Island

    func rideTrackingDynamicIsland(context: ActivityViewContext<GenericLiveActivityAttributes>) -> DynamicIsland {
        let eta = context.state.data["eta"]?.stringValue ?? "--"
        let progress = context.state.data["progress"]?.doubleValue ?? 0

        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                Label(sharedDefaults.string(forKey: "attr_driverName") ?? "",
                      systemImage: "car.fill")
                    .font(.caption)
            }
            DynamicIslandExpandedRegion(.trailing) {
                Text(eta)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            DynamicIslandExpandedRegion(.bottom) {
                ProgressView(value: progress)
                    .tint(.green)
            }
        } compactLeading: {
            Image(systemName: "car.fill")
                .foregroundColor(.green)
        } compactTrailing: {
            Text(eta)
                .font(.caption)
                .foregroundColor(.green)
        } minimal: {
            Image(systemName: "car.fill")
                .foregroundColor(.green)
        }
    }
}
