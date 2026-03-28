import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Manages iOS Live Activities via ActivityKit.
@available(iOS 16.2, *)
class LiveActivityManager {

    var onPushTokenUpdate: ((String, String) -> Void)?
    var onActivityEvent: ((String, String, [String: Any]?) -> Void)?

    private var activities: [String: Activity<GenericLiveActivityAttributes>] = [:]
    private let pushTokenManager = PushTokenManager()
    private var dataBridge: LiveActivityDataBridge?
    private var tokenTasks: [String: Task<Void, Never>] = [:]

    init(appGroupId: String? = nil) {
        if let groupId = appGroupId {
            dataBridge = LiveActivityDataBridge(appGroupId: groupId)
        }
    }

    // MARK: - Start

    @available(iOS 16.2, *)
    func startActivity(type: String, attributes: [String: Any],
                       state: [String: Any], staleAfterMs: Int?,
                       result: @escaping (Any?) -> Void) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            NSLog("[NotifyPilot] Live Activities not enabled")
            result(nil)
            return
        }

        let activityAttributes = GenericLiveActivityAttributes(type: type)
        let contentState = GenericLiveActivityAttributes.ContentState(data: state)

        var staleDate: Date? = nil
        if let ms = staleAfterMs {
            staleDate = Date().addingTimeInterval(Double(ms) / 1000.0)
        }

        let activityContent = ActivityContent(state: contentState, staleDate: staleDate)

        do {
            let activity = try Activity<GenericLiveActivityAttributes>.request(
                attributes: activityAttributes,
                content: activityContent,
                pushType: .token
            )

            activities[activity.id] = activity

            dataBridge?.writeAttributes(attributes, forActivityId: activity.id)
            dataBridge?.writeState(state, forActivityId: activity.id)

            // Monitor push token updates
            let task = Task {
                for await tokenData in activity.pushTokenUpdates {
                    let token = tokenData.map { String(format: "%02x", $0) }.joined()
                    self.pushTokenManager.setToken(token, forActivityId: activity.id)
                    self.onPushTokenUpdate?(activity.id, token)
                }
            }
            tokenTasks[activity.id] = task

            NSLog("[NotifyPilot] Started Live Activity: \(activity.id)")
            result(activity.id)
        } catch {
            NSLog("[NotifyPilot] Failed to start Live Activity: \(error)")
            result(nil)
        }
    }

    // MARK: - Update

    @available(iOS 16.2, *)
    func updateActivity(activityId: String, state: [String: Any],
                        result: @escaping (Any?) -> Void) {
        guard let activity = activities[activityId] else {
            result(false)
            return
        }

        let contentState = GenericLiveActivityAttributes.ContentState(data: state)
        let content = ActivityContent(state: contentState, staleDate: nil)

        Task {
            await activity.update(content)
            self.dataBridge?.writeState(state, forActivityId: activityId)
            result(true)
        }
    }

    // MARK: - End

    @available(iOS 16.2, *)
    func endActivity(activityId: String, finalState: [String: Any]?,
                     dismissPolicy: String, result: @escaping (Any?) -> Void) {
        guard let activity = activities[activityId] else {
            result(false)
            return
        }

        let policy: ActivityUIDismissalPolicy
        switch dismissPolicy {
        case "immediate": policy = .immediate
        default: policy = .default
        }

        Task {
            if let state = finalState {
                let contentState = GenericLiveActivityAttributes.ContentState(data: state)
                let content = ActivityContent(state: contentState, staleDate: nil)
                await activity.end(content, dismissalPolicy: policy)
            } else {
                await activity.end(nil, dismissalPolicy: policy)
            }

            self.tokenTasks[activityId]?.cancel()
            self.tokenTasks.removeValue(forKey: activityId)
            self.pushTokenManager.removeToken(forActivityId: activityId)
            self.dataBridge?.clear(forActivityId: activityId)
            self.activities.removeValue(forKey: activityId)

            result(true)
        }
    }

    @available(iOS 16.2, *)
    func endAllActivities(type: String?, result: @escaping (Any?) -> Void) {
        Task {
            let toEnd = activities

            for (activityId, activity) in toEnd {
                await activity.end(nil, dismissalPolicy: .immediate)
                tokenTasks[activityId]?.cancel()
                tokenTasks.removeValue(forKey: activityId)
                pushTokenManager.removeToken(forActivityId: activityId)
                dataBridge?.clear(forActivityId: activityId)
            }

            if type == nil {
                activities.removeAll()
            } else {
                for key in toEnd.keys {
                    activities.removeValue(forKey: key)
                }
            }

            result(true)
        }
    }

    // MARK: - Query

    @available(iOS 16.2, *)
    static func isSupported() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    @available(iOS 16.2, *)
    static func hasDynamicIsland() -> Bool {
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        guard let m = model else { return false }
        let diModels = ["iPhone15,2","iPhone15,3","iPhone15,4","iPhone15,5",
                        "iPhone16,1","iPhone16,2","iPhone17,1","iPhone17,2",
                        "iPhone17,3","iPhone17,4"]
        return diModels.contains(m)
    }

    func getActiveActivities() -> [[String: Any]] {
        return activities.map { (id, _) in
            var info: [String: Any] = ["id": id, "type": "", "status": "active"]
            if let token = pushTokenManager.getToken(forActivityId: id) {
                info["pushToken"] = token
            }
            return info
        }
    }

    func getActivityStatus(activityId: String) -> String {
        guard activities[activityId] != nil else { return "ended" }
        return "active"
    }

    func getPushToken(activityId: String) -> String? {
        return pushTokenManager.getToken(forActivityId: activityId)
    }
}

#else

// Stub for platforms without ActivityKit
class LiveActivityManager {
    var onPushTokenUpdate: ((String, String) -> Void)?
    var onActivityEvent: ((String, String, [String: Any]?) -> Void)?

    func startActivity(type: String, attributes: [String: Any],
                       state: [String: Any], staleAfterMs: Int?,
                       result: @escaping (Any?) -> Void) { result(nil) }
    func updateActivity(activityId: String, state: [String: Any],
                        result: @escaping (Any?) -> Void) { result(false) }
    func endActivity(activityId: String, finalState: [String: Any]?,
                     dismissPolicy: String, result: @escaping (Any?) -> Void) { result(false) }
    func endAllActivities(type: String?, result: @escaping (Any?) -> Void) { result(false) }
    static func isSupported() -> Bool { return false }
    static func hasDynamicIsland() -> Bool { return false }
    func getActiveActivities() -> [[String: Any]] { return [] }
    func getActivityStatus(activityId: String) -> String { return "ended" }
    func getPushToken(activityId: String) -> String? { return nil }
}

#endif
