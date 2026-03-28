// NotifyPilotWidgetBundle.swift
// Main entry point for the Widget Extension.
// Copy into your Widget Extension target.
// Uncomment/add the Live Activity widgets you need.

import SwiftUI
import WidgetKit

@main
struct NotifyPilotWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Add your Live Activity widgets here:
        RideTrackingLiveActivity()
        DeliveryTrackingLiveActivity()
        // SportsScoreLiveActivity()
        // TimerLiveActivity()
    }
}
