// DeliveryTrackingLiveActivity.swift
// Example Live Activity for food delivery apps (Swiggy/Zomato style).
// Copy into your Widget Extension target and customize.

import ActivityKit
import SwiftUI
import WidgetKit

struct DeliveryTrackingLiveActivity: Widget {
    let sharedDefaults = UserDefaults(suiteName: "group.YOUR_APP_GROUP_ID")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GenericLiveActivityAttributes.self) { context in
            if context.attributes.type == "food_delivery" {
                deliveryLockScreen(context: context)
            }
        } dynamicIsland: { context in
            if context.attributes.type == "food_delivery" {
                deliveryDynamicIsland(context: context)
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
    func deliveryLockScreen(context: ActivityViewContext<GenericLiveActivityAttributes>) -> some View {
        let restaurant = sharedDefaults.string(forKey: "attr_restaurantName") ?? "Restaurant"
        let orderNumber = sharedDefaults.string(forKey: "attr_orderNumber") ?? ""
        let status = context.state.data["status"]?.stringValue ?? "preparing"
        let eta = context.state.data["eta"]?.stringValue ?? "--"
        let deliveryPerson = context.state.data["deliveryPerson"]?.stringValue
        let progress = context.state.data["progress"]?.doubleValue ?? 0

        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(restaurant)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(orderNumber)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text(eta)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }

            // Status steps
            HStack(spacing: 4) {
                statusDot(active: true)
                statusLine(active: status != "preparing")
                statusDot(active: status != "preparing")
                statusLine(active: status == "on_the_way" || status == "delivered")
                statusDot(active: status == "on_the_way" || status == "delivered")
                statusLine(active: status == "delivered")
                statusDot(active: status == "delivered")
            }

            HStack {
                Text(statusLabel(status))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let person = deliveryPerson {
                    Label(person, systemImage: "bicycle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
    }

    func deliveryDynamicIsland(context: ActivityViewContext<GenericLiveActivityAttributes>) -> DynamicIsland {
        let eta = context.state.data["eta"]?.stringValue ?? "--"
        let status = context.state.data["status"]?.stringValue ?? "preparing"

        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                Label(sharedDefaults.string(forKey: "attr_restaurantName") ?? "",
                      systemImage: "bag.fill")
                    .font(.caption)
            }
            DynamicIslandExpandedRegion(.trailing) {
                Text(eta)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            DynamicIslandExpandedRegion(.bottom) {
                Text(statusLabel(status))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } compactLeading: {
            Image(systemName: "bag.fill")
                .foregroundColor(.orange)
        } compactTrailing: {
            Text(eta)
                .font(.caption)
                .foregroundColor(.orange)
        } minimal: {
            Image(systemName: "bag.fill")
                .foregroundColor(.orange)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    func statusDot(active: Bool) -> some View {
        Circle()
            .fill(active ? Color.orange : Color.gray.opacity(0.3))
            .frame(width: 8, height: 8)
    }

    @ViewBuilder
    func statusLine(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.orange : Color.gray.opacity(0.3))
            .frame(height: 2)
    }

    func statusLabel(_ status: String) -> String {
        switch status {
        case "preparing": return "Preparing your order"
        case "picked_up": return "Order picked up"
        case "on_the_way": return "On the way"
        case "delivered": return "Delivered!"
        default: return status.capitalized
        }
    }
}
