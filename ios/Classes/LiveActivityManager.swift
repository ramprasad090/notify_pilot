import Foundation
import ActivityKit

/// Manages iOS Live Activities via ActivityKit.
/// Supports starting, updating, ending, and querying Live Activities
/// using GenericLiveActivityAttributes for Flutter interop.
@available(iOS 16.2, *)
class LiveActivityManager {

    /// Callback invoked when a push token is updated for an activity.
    /// Parameters: (activityId: String, pushToken: String)
    var onPushTokenUpdate: ((String, String) -> Void)?

    /// Tracks active activities by their Flutter-assigned ID.
    private var activities: [String: Activity<GenericLiveActivityAttributes>] = [:]

    /// Manages push tokens for each activity.
    private let pushTokenManager = PushTokenManager()

    /// Data bridge for sharing data with Widget Extension.
    private var dataBridge: LiveActivityDataBridge?

    /// Tasks monitoring push token updates per activity.
    private var tokenTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Init

    /// Creates a new manager with an optional App Group ID for data bridging.
    init(appGroupId: String? = nil) {
        if let groupId = appGroupId {
            dataBridge = LiveActivityDataBridge(appGroupId: groupId)
        }
    }

    // MARK: - Start

    /// Starts a new Live Activity with the given parameters.
    ///
    /// - Parameters:
    ///   - activityId: A unique identifier for tracking this activity.
    ///   - type: The activity type string stored in attributes.
    ///   - attributes: Static attribute data for the activity.
    ///   - state: Initial content state data.
    ///   - staleDate: Optional date after which the activity becomes stale.
    /// - Returns: The activity ID on success, or nil on failure.
    func start(
        activityId: String,
        type: String,
        attributes: [String: Any],
        state: [String: Any],
        staleDate: Date? = nil
    ) -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            NSLog("[NotifyPilot] LiveActivityManager: Activities are not enabled")
            return nil
        }

        let activityAttributes = GenericLiveActivityAttributes(type: type)
        let contentState = GenericLiveActivityAttributes.ContentState(data: state)

        let content = ActivityContent(
            state: contentState,
            staleDate: staleDate
        )

        do {
            let activity = try Activity<GenericLiveActivityAttributes>.request(
                attributes: activityAttributes,
                content: content,
                pushType: .token
            )

            activities[activityId] = activity

            // Write data to shared storage for Widget Extension
            dataBridge?.writeAttributes(attributes, forActivityId: activityId)
            dataBridge?.writeState(state, forActivityId: activityId)

            // Monitor push token updates
            monitorPushTokenUpdates(activityId: activityId, activity: activity)

            NSLog("[NotifyPilot] LiveActivityManager: Started activity '\(activityId)'")
            return activityId
        } catch {
            NSLog("[NotifyPilot] LiveActivityManager: Failed to start activity: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Update

    /// Updates the content state of an existing Live Activity.
    ///
    /// - Parameters:
    ///   - activityId: The identifier of the activity to update.
    ///   - state: New content state data.
    ///   - alertTitle: Optional title for the update alert.
    ///   - alertBody: Optional body for the update alert.
    func update(
        activityId: String,
        state: [String: Any],
        alertTitle: String? = nil,
        alertBody: String? = nil
    ) async -> Bool {
        guard let activity = activities[activityId] else {
            NSLog("[NotifyPilot] LiveActivityManager: No active activity found for '\(activityId)'")
            return false
        }

        let contentState = GenericLiveActivityAttributes.ContentState(data: state)

        var alertConfig: AlertConfiguration? = nil
        if let title = alertTitle, let body = alertBody {
            alertConfig = AlertConfiguration(
                title: LocalizedStringResource(stringLiteral: title),
                body: LocalizedStringResource(stringLiteral: body),
                sound: .default
            )
        }

        let content = ActivityContent(
            state: contentState,
            staleDate: nil
        )

        do {
            await activity.update(content, alertConfiguration: alertConfig)

            // Update shared storage
            dataBridge?.writeState(state, forActivityId: activityId)

            NSLog("[NotifyPilot] LiveActivityManager: Updated activity '\(activityId)'")
            return true
        }
    }

    // MARK: - End

    /// Ends a specific Live Activity.
    ///
    /// - Parameters:
    ///   - activityId: The identifier of the activity to end.
    ///   - state: Optional final content state.
    ///   - dismissPolicy: How the activity should be dismissed ("immediate" or "default").
    func end(
        activityId: String,
        state: [String: Any]? = nil,
        dismissPolicy: String = "default"
    ) async -> Bool {
        guard let activity = activities[activityId] else {
            NSLog("[NotifyPilot] LiveActivityManager: No active activity found for '\(activityId)'")
            return false
        }

        let contentState: GenericLiveActivityAttributes.ContentState
        if let stateData = state {
            contentState = GenericLiveActivityAttributes.ContentState(data: stateData)
        } else {
            contentState = GenericLiveActivityAttributes.ContentState(data: [:])
        }

        let content = ActivityContent(
            state: contentState,
            staleDate: nil
        )

        let policy: ActivityUIDismissalPolicy
        switch dismissPolicy {
        case "immediate":
            policy = .immediate
        default:
            policy = .default
        }

        await activity.end(content, dismissalPolicy: policy)

        // Clean up
        cancelTokenMonitor(activityId: activityId)
        pushTokenManager.removeToken(forActivityId: activityId)
        dataBridge?.clear(forActivityId: activityId)
        activities.removeValue(forKey: activityId)

        NSLog("[NotifyPilot] LiveActivityManager: Ended activity '\(activityId)'")
        return true
    }

    /// Ends all active Live Activities.
    func endAll() async {
        for (activityId, activity) in activities {
            let content = ActivityContent(
                state: GenericLiveActivityAttributes.ContentState(data: [:]),
                staleDate: nil
            )
            await activity.end(content, dismissalPolicy: .immediate)

            cancelTokenMonitor(activityId: activityId)
            pushTokenManager.removeToken(forActivityId: activityId)
            dataBridge?.clear(forActivityId: activityId)
        }
        activities.removeAll()

        NSLog("[NotifyPilot] LiveActivityManager: Ended all activities")
    }

    // MARK: - Query

    /// Returns whether Live Activities are supported on this device.
    static var isSupported: Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Returns whether the device has a Dynamic Island.
    /// This is a best-effort check based on device model.
    static var hasDynamicIsland: Bool {
        // Devices with Dynamic Island: iPhone 14 Pro and later Pro models, iPhone 15 and later
        // We check by seeing if the device name suggests a supported model.
        // A more reliable approach is to check the hardware model string.
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }

        guard let model = modelCode else { return false }

        // iPhone 14 Pro (iPhone15,2), iPhone 14 Pro Max (iPhone15,3)
        // iPhone 15 series (iPhone15,4/5, iPhone16,1/2)
        // iPhone 16 series (iPhone17,x)
        let dynamicIslandModels = [
            "iPhone15,2", "iPhone15,3",       // 14 Pro, 14 Pro Max
            "iPhone15,4", "iPhone15,5",       // 15, 15 Plus
            "iPhone16,1", "iPhone16,2",       // 15 Pro, 15 Pro Max
            "iPhone17,1", "iPhone17,2",       // 16 Pro, 16 Pro Max
            "iPhone17,3", "iPhone17,4",       // 16, 16 Plus
        ]

        return dynamicIslandModels.contains(model)
    }

    /// Returns a list of currently active activity IDs and their states.
    func getActive() -> [[String: Any]] {
        var result: [[String: Any]] = []

        for (activityId, activity) in activities {
            var info: [String: Any] = [
                "activityId": activityId,
                "state": activity.activityState.statusString,
            ]

            if let token = pushTokenManager.getToken(forActivityId: activityId) {
                info["pushToken"] = token
            }

            result.append(info)
        }

        return result
    }

    /// Returns the status of a specific activity.
    func getStatus(activityId: String) -> String? {
        guard let activity = activities[activityId] else { return nil }
        return activity.activityState.statusString
    }

    /// Returns the push token for a specific activity.
    func getPushToken(activityId: String) -> String? {
        return pushTokenManager.getToken(forActivityId: activityId)
    }

    // MARK: - Private

    /// Monitors push token updates for the given activity via an async Task.
    private func monitorPushTokenUpdates(activityId: String, activity: Activity<GenericLiveActivityAttributes>) {
        let task = Task {
            for await tokenData in activity.pushTokenUpdates {
                let token = PushTokenManager.hexString(from: tokenData)
                self.pushTokenManager.setToken(token, forActivityId: activityId)
                self.onPushTokenUpdate?(activityId, token)

                NSLog("[NotifyPilot] LiveActivityManager: Push token updated for '\(activityId)'")
            }
        }
        tokenTasks[activityId] = task
    }

    /// Cancels the push token monitoring task for the given activity.
    private func cancelTokenMonitor(activityId: String) {
        tokenTasks[activityId]?.cancel()
        tokenTasks.removeValue(forKey: activityId)
    }
}

// MARK: - ActivityState Extension

@available(iOS 16.2, *)
private extension ActivityState {
    /// Returns a human-readable string representation of the activity state.
    var statusString: String {
        switch self {
        case .active:
            return "active"
        case .ended:
            return "ended"
        case .dismissed:
            return "dismissed"
        case .stale:
            return "stale"
        @unknown default:
            return "unknown"
        }
    }
}
