import Flutter
import UIKit
import UserNotifications

/// Main Flutter plugin for NotifyPilot.
/// Implements FlutterPlugin and UNUserNotificationCenterDelegate to handle
/// all notification-related method calls from Dart.
@available(iOS 13.0, *)
public class NotifyPilotPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {

    private var channel: FlutterMethodChannel?
    private let center = UNUserNotificationCenter.current()

    private let categoryManager = CategoryManager()
    private lazy var displayManager = NotificationDisplayManager(categoryManager: categoryManager)
    private let scheduleManager = ScheduleManager()
    private let actionHandler = ActionHandler()
    private let historyStore = HistoryStore()
    private let fcmHandler = FcmHandler()
    private let permissionHelper = PermissionHelper()
    private var liveActivityManager: Any? // LiveActivityManager (iOS 16.2+)
    private var callKitManager: CallKitManager?
    private let pushKitManager = PushKitManager()
    private let callNotificationHelper = CallNotificationHelper()
    private let mediaDownloader = MediaDownloader()
    private let criticalAlertHelper = CriticalAlertHelper()
    private let mediaSessionHelper = MediaSessionHelper()

    /// Holds the launch notification response if the app was opened from a notification tap.
    private var launchNotificationResponse: UNNotificationResponse?

    // MARK: - FlutterPlugin Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "dev.notify_pilot/channel",
            binaryMessenger: registrar.messenger()
        )
        let instance = NotifyPilotPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Set as notification center delegate
        let center = UNUserNotificationCenter.current()
        center.delegate = instance

        // Register for application lifecycle
        registrar.addApplicationDelegate(instance)
    }

    // MARK: - Method Call Routing

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "initialize":
            handleInitialize(args: args, result: result)
        case "show":
            handleShow(args: args, result: result)
        case "scheduleAt":
            handleScheduleAt(args: args, result: result)
        case "scheduleAfter":
            handleScheduleAfter(args: args, result: result)
        case "scheduleCron":
            handleScheduleCron(args: args, result: result)
        case "cancel":
            handleCancel(args: args, result: result)
        case "cancelGroup":
            handleCancelGroup(args: args, result: result)
        case "cancelAll":
            handleCancelAll(result: result)
        case "cancelSchedule":
            handleCancelSchedule(args: args, result: result)
        case "getActive":
            handleGetActive(result: result)
        case "getScheduled":
            handleGetScheduled(result: result)
        case "createChannel":
            handleCreateChannel(args: args, result: result)
        case "deleteChannel":
            handleDeleteChannel(args: args, result: result)
        case "requestPermission":
            handleRequestPermission(result: result)
        case "getPermission":
            handleGetPermission(result: result)
        case "setBadge":
            handleSetBadge(args: args, result: result)
        case "getFcmToken":
            handleGetFcmToken(result: result)
        case "subscribeTopic":
            handleSubscribeTopic(args: args, result: result)
        case "unsubscribeTopic":
            handleUnsubscribeTopic(args: args, result: result)
        case "getHistory":
            handleGetHistory(args: args, result: result)
        case "clearHistory":
            handleClearHistory(args: args, result: result)
        case "getUnreadCount":
            handleGetUnreadCount(args: args, result: result)
        case "markRead":
            handleMarkRead(args: args, result: result)
        case "openSettings":
            handleOpenSettings(result: result)
        // Live Activities
        case "startLiveActivity":
            handleStartLiveActivity(args: args, result: result)
        case "updateLiveActivity":
            handleUpdateLiveActivity(args: args, result: result)
        case "endLiveActivity":
            handleEndLiveActivity(args: args, result: result)
        case "endAllLiveActivities":
            handleEndAllLiveActivities(args: args, result: result)
        case "getLiveActivityPushToken":
            handleGetLiveActivityPushToken(args: args, result: result)
        case "isLiveActivitySupported":
            handleIsLiveActivitySupported(result: result)
        case "hasDynamicIsland":
            handleHasDynamicIsland(result: result)
        case "getActiveLiveActivities":
            handleGetActiveLiveActivities(result: result)
        case "getLiveActivityStatus":
            handleGetLiveActivityStatus(args: args, result: result)
        // v1.0.2
        case "updateProgress":
            handleUpdateProgress(args: args, result: result)
        case "setMediaPlaybackState":
            handleSetMediaPlaybackState(args: args, result: result)
        case "hasCriticalAlertEntitlement":
            handleHasCriticalAlertEntitlement(result: result)
        // Caller Notification (CallKit / PushKit)
        case "showIncomingCall":
            handleShowIncomingCall(args: args, result: result)
        case "showOutgoingCall":
            handleShowOutgoingCall(args: args, result: result)
        case "setCallConnected":
            handleSetCallConnected(args: args, result: result)
        case "endCall":
            handleEndCall(args: args, result: result)
        case "showMissedCall":
            handleShowMissedCall(args: args, result: result)
        case "getActiveCalls":
            handleGetActiveCalls(result: result)
        case "hideIncomingCall":
            handleHideIncomingCall(args: args, result: result)
        case "registerVoIPPush":
            handleRegisterVoIPPush(result: result)
        case "getVoIPToken":
            handleGetVoIPToken(result: result)
        case "isCallKitAvailable":
            handleIsCallKitAvailable(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when a notification is about to be presented while the app is in the foreground.
    /// Shows the notification with alert, badge, and sound.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound, .list])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }

    /// Called when the user interacts with a notification (tap or action button).
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let (eventType, eventData) = actionHandler.extractEvent(from: response)

        // Update history status
        if let notifId = eventData["notificationId"] as? Int {
            switch eventType {
            case "onTap":
                historyStore.updateStatus(id: notifId, status: 1) // opened
            case "onDismissed":
                historyStore.updateStatus(id: notifId, status: 2) // dismissed
            case "onAction":
                let actionId = eventData["actionId"] as? String
                historyStore.updateStatus(id: notifId, status: 3, actionTaken: actionId) // action
            default:
                break
            }
        }

        // Check for cron reschedule
        let userInfo = response.notification.request.content.userInfo
        if let tag = userInfo["tag"] as? String {
            channel?.invokeMethod("onCronFired", arguments: ["tag": tag])
        }

        // Send event to Dart
        if channel != nil {
            channel?.invokeMethod(eventType, arguments: eventData)
        } else {
            // Store for later delivery if channel not ready
            if eventType == "onTap" {
                launchNotificationResponse = response
            }
        }

        completionHandler()
    }

    // MARK: - Application Delegate

    /// Delivers any stored launch notification after the engine is connected.
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any]? = nil
    ) -> Bool {
        return true
    }

    // MARK: - Handler Implementations

    private func handleInitialize(args: [String: Any], result: @escaping FlutterResult) {
        // Deliver launch notification if one was stored
        if let response = launchNotificationResponse {
            var (eventType, eventData) = actionHandler.extractEvent(from: response)
            if eventType == "onTap" {
                eventData["launchedApp"] = true
                channel?.invokeMethod(eventType, arguments: eventData)
            }
            launchNotificationResponse = nil
        }
        result(true)
    }

    private func handleShow(args: [String: Any], result: @escaping FlutterResult) {
        let notifId = args["id"] as? Int ?? Int.random(in: 1...Int.max)
        let identifier = String(notifId)

        displayManager.buildContent(from: args) { [weak self] content in
            // Configure interruption level for alarm/call channel types (v1.0.2)
            let channelType = args["channelType"] as? String
            if channelType == "alarm" || channelType == "call" {
                self?.criticalAlertHelper.configureHighPriority(content: content) { configuredContent in
                    self?.postNotification(identifier: identifier, content: configuredContent, args: args, notifId: notifId, result: result)
                }
            } else if let fullscreen = args["fullscreen"] as? Bool, fullscreen {
                // Fullscreen intent: use time-sensitive on iOS 15+
                if #available(iOS 15.0, *) {
                    content.interruptionLevel = .timeSensitive
                }
                self?.postNotification(identifier: identifier, content: content, args: args, notifId: notifId, result: result)
            } else {
                self?.postNotification(identifier: identifier, content: content, args: args, notifId: notifId, result: result)
            }
        }
    }

    /// Posts the notification request to the notification center.
    private func postNotification(
        identifier: String,
        content: UNMutableNotificationContent,
        args: [String: Any],
        notifId: Int,
        result: @escaping FlutterResult
    ) {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(request) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("[NotifyPilot] Show error: \(error.localizedDescription)")
                    result(FlutterError(code: "SHOW_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    // Record in history
                    self?.recordHistory(args: args, id: notifId)
                    result(notifId)
                }
            }
        }
    }

    private func handleScheduleAt(args: [String: Any], result: @escaping FlutterResult) {
        let notifId = args["id"] as? Int ?? Int.random(in: 1...Int.max)
        let identifier = String(notifId)

        guard let trigger = scheduleManager.createCalendarTrigger(from: args) else {
            result(FlutterError(code: "INVALID_DATE", message: "Invalid date components for scheduleAt", details: nil))
            return
        }

        displayManager.buildContent(from: args) { [weak self] content in
            self?.scheduleManager.schedule(identifier: identifier, content: content, trigger: trigger) { success in
                if success {
                    self?.recordHistory(args: args, id: notifId)
                    result(notifId)
                } else {
                    result(FlutterError(code: "SCHEDULE_ERROR", message: "Failed to schedule notification", details: nil))
                }
            }
        }
    }

    private func handleScheduleAfter(args: [String: Any], result: @escaping FlutterResult) {
        let notifId = args["id"] as? Int ?? Int.random(in: 1...Int.max)
        let identifier = String(notifId)
        let seconds = args["seconds"] as? Double ?? 0

        guard let trigger = scheduleManager.createTimeIntervalTrigger(seconds: seconds) else {
            result(FlutterError(code: "INVALID_DELAY", message: "Delay must be greater than 0", details: nil))
            return
        }

        displayManager.buildContent(from: args) { [weak self] content in
            self?.scheduleManager.schedule(identifier: identifier, content: content, trigger: trigger) { success in
                if success {
                    self?.recordHistory(args: args, id: notifId)
                    result(notifId)
                } else {
                    result(FlutterError(code: "SCHEDULE_ERROR", message: "Failed to schedule notification", details: nil))
                }
            }
        }
    }

    private func handleScheduleCron(args: [String: Any], result: @escaping FlutterResult) {
        let tag = args["tag"] as? String ?? UUID().uuidString

        guard let trigger = scheduleManager.createCronTrigger(from: args) else {
            result(FlutterError(code: "INVALID_CRON", message: "Invalid cron components", details: nil))
            return
        }

        // Save metadata for rescheduling
        scheduleManager.saveMetadata(tag: tag, data: args)

        displayManager.buildContent(from: args) { [weak self] content in
            // Store the tag in userInfo so we can identify cron notifications on fire
            var userInfo = content.userInfo
            userInfo["tag"] = tag
            content.userInfo = userInfo

            self?.scheduleManager.schedule(identifier: "cron_\(tag)", content: content, trigger: trigger) { success in
                result(success)
            }
        }
    }

    private func handleCancel(args: [String: Any], result: @escaping FlutterResult) {
        if let id = args["id"] as? Int {
            let identifier = String(id)
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            result(true)
        } else {
            result(false)
        }
    }

    private func handleCancelGroup(args: [String: Any], result: @escaping FlutterResult) {
        guard let group = args["group"] as? String else {
            result(false)
            return
        }

        center.getDeliveredNotifications { [weak self] notifications in
            let identifiers = notifications
                .filter { $0.request.content.threadIdentifier == group }
                .map { $0.request.identifier }

            self?.center.removeDeliveredNotifications(withIdentifiers: identifiers)

            // Also remove pending ones in the same group
            self?.center.getPendingNotificationRequests { requests in
                let pendingIds = requests
                    .filter { $0.content.threadIdentifier == group }
                    .map { $0.identifier }
                self?.center.removePendingNotificationRequests(withIdentifiers: pendingIds)

                DispatchQueue.main.async {
                    result(true)
                }
            }
        }
    }

    private func handleCancelAll(result: @escaping FlutterResult) {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        scheduleManager.clearAllMetadata()
        result(true)
    }

    private func handleCancelSchedule(args: [String: Any], result: @escaping FlutterResult) {
        guard let tag = args["tag"] as? String else {
            result(false)
            return
        }
        scheduleManager.cancel(identifier: "cron_\(tag)")
        scheduleManager.removeMetadata(tag: tag)
        result(true)
    }

    private func handleGetActive(result: @escaping FlutterResult) {
        center.getDeliveredNotifications { notifications in
            let list: [[String: Any]] = notifications.map { notification in
                let content = notification.request.content
                var map: [String: Any] = [
                    "id": notification.request.identifier,
                    "title": content.title,
                    "body": content.body,
                    "threadIdentifier": content.threadIdentifier,
                ]
                if !content.userInfo.isEmpty {
                    if let notifId = content.userInfo["notificationId"] as? Int {
                        map["notificationId"] = notifId
                    }
                    if let payload = content.userInfo["payload"] as? [String: Any] {
                        map["payload"] = payload
                    }
                }
                map["date"] = Int(notification.date.timeIntervalSince1970 * 1000)
                return map
            }
            DispatchQueue.main.async {
                result(list)
            }
        }
    }

    private func handleGetScheduled(result: @escaping FlutterResult) {
        scheduleManager.getPendingRequests { requests in
            result(requests)
        }
    }

    private func handleCreateChannel(args: [String: Any], result: @escaping FlutterResult) {
        // Channels are an Android concept. On iOS this is a no-op but returns success.
        result(true)
    }

    private func handleDeleteChannel(args: [String: Any], result: @escaping FlutterResult) {
        // Channels are an Android concept. On iOS this is a no-op but returns success.
        result(true)
    }

    private func handleRequestPermission(result: @escaping FlutterResult) {
        permissionHelper.requestAuthorization { granted in
            result(granted)
        }
    }

    private func handleGetPermission(result: @escaping FlutterResult) {
        permissionHelper.getPermissionStatus { status in
            result(status)
        }
    }

    private func handleSetBadge(args: [String: Any], result: @escaping FlutterResult) {
        let count = args["count"] as? Int ?? 0
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
            result(true)
        }
    }

    private func handleGetFcmToken(result: @escaping FlutterResult) {
        fcmHandler.getToken { token in
            result(token)
        }
    }

    private func handleSubscribeTopic(args: [String: Any], result: @escaping FlutterResult) {
        guard let topic = args["topic"] as? String else {
            result(false)
            return
        }
        fcmHandler.subscribeTopic(topic) { success in
            result(success)
        }
    }

    private func handleUnsubscribeTopic(args: [String: Any], result: @escaping FlutterResult) {
        guard let topic = args["topic"] as? String else {
            result(false)
            return
        }
        fcmHandler.unsubscribeTopic(topic) { success in
            result(success)
        }
    }

    private func handleGetHistory(args: [String: Any], result: @escaping FlutterResult) {
        let entries = historyStore.query(args)
        result(entries)
    }

    private func handleClearHistory(args: [String: Any], result: @escaping FlutterResult) {
        if let olderThanMs = args["olderThanMs"] as? Int {
            historyStore.clearOlderThan(milliseconds: olderThanMs)
        } else {
            historyStore.clearAll()
        }
        result(true)
    }

    private func handleGetUnreadCount(args: [String: Any], result: @escaping FlutterResult) {
        let group = args["group"] as? String
        let count = historyStore.getUnreadCount(group: group)
        result(count)
    }

    private func handleMarkRead(args: [String: Any], result: @escaping FlutterResult) {
        if let id = args["id"] as? Int {
            historyStore.markRead(id: id)
        } else if let all = args["all"] as? Bool, all {
            let group = args["group"] as? String
            historyStore.markAllRead(group: group)
        }
        result(true)
    }

    private func handleOpenSettings(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:]) { success in
                    result(success)
                }
            } else {
                result(false)
            }
        }
    }

    // MARK: - Live Activity Handlers

    private func getOrCreateLiveActivityManager() -> LiveActivityManager? {
        if #available(iOS 16.2, *) {
            if liveActivityManager == nil {
                let manager = LiveActivityManager()
                manager.onPushTokenUpdate = { [weak self] activityId, token in
                    self?.channel?.invokeMethod("onLiveActivityPushTokenUpdate", arguments: [
                        "activityId": activityId,
                        "pushToken": token,
                    ])
                }
                manager.onActivityEvent = { [weak self] activityId, event, data in
                    var args: [String: Any] = [
                        "activityId": activityId,
                        "event": event,
                    ]
                    if let data = data {
                        args["state"] = data
                    }
                    self?.channel?.invokeMethod("onLiveActivityEvent", arguments: args)
                }
                liveActivityManager = manager
            }
            return liveActivityManager as? LiveActivityManager
        }
        return nil
    }

    private func handleStartLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
        guard let manager = getOrCreateLiveActivityManager() else {
            result(FlutterError(code: "UNSUPPORTED", message: "Live Activities require iOS 16.2+", details: nil))
            return
        }
        if #available(iOS 16.2, *) {
            (manager as LiveActivityManager).startActivity(
                type: args["type"] as? String ?? "",
                attributes: args["attributes"] as? [String: Any] ?? [:],
                state: args["state"] as? [String: Any] ?? [:],
                staleAfterMs: args["staleAfterMs"] as? Int,
                result: result
            )
        }
    }

    private func handleUpdateLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
        guard let manager = getOrCreateLiveActivityManager() else {
            result(false)
            return
        }
        if #available(iOS 16.2, *) {
            (manager as LiveActivityManager).updateActivity(
                activityId: args["activityId"] as? String ?? "",
                state: args["state"] as? [String: Any] ?? [:],
                result: result
            )
        }
    }

    private func handleEndLiveActivity(args: [String: Any], result: @escaping FlutterResult) {
        guard let manager = getOrCreateLiveActivityManager() else {
            result(false)
            return
        }
        if #available(iOS 16.2, *) {
            let dismissMap = args["dismissPolicy"] as? [String: Any] ?? [:]
            let dismissType = dismissMap["type"] as? String ?? "default"
            (manager as LiveActivityManager).endActivity(
                activityId: args["activityId"] as? String ?? "",
                finalState: args["finalState"] as? [String: Any],
                dismissPolicy: dismissType,
                result: result
            )
        }
    }

    private func handleEndAllLiveActivities(args: [String: Any], result: @escaping FlutterResult) {
        guard let manager = getOrCreateLiveActivityManager() else {
            result(false)
            return
        }
        if #available(iOS 16.2, *) {
            (manager as LiveActivityManager).endAllActivities(
                type: args["type"] as? String,
                result: result
            )
        }
    }

    private func handleGetLiveActivityPushToken(args: [String: Any], result: @escaping FlutterResult) {
        guard let manager = getOrCreateLiveActivityManager() else {
            result(nil)
            return
        }
        if #available(iOS 16.2, *) {
            let token = (manager as LiveActivityManager).getPushToken(
                activityId: args["activityId"] as? String ?? ""
            )
            result(token)
        }
    }

    private func handleIsLiveActivitySupported(result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            result(LiveActivityManager.isSupported())
        } else {
            result(false)
        }
    }

    private func handleHasDynamicIsland(result: @escaping FlutterResult) {
        if #available(iOS 16.2, *) {
            result(LiveActivityManager.hasDynamicIsland())
        } else {
            result(false)
        }
    }

    private func handleGetActiveLiveActivities(result: @escaping FlutterResult) {
        guard let manager = getOrCreateLiveActivityManager() else {
            result([])
            return
        }
        if #available(iOS 16.2, *) {
            result((manager as LiveActivityManager).getActiveActivities())
        }
    }

    private func handleGetLiveActivityStatus(args: [String: Any], result: @escaping FlutterResult) {
        guard let manager = getOrCreateLiveActivityManager() else {
            result("ended")
            return
        }
        if #available(iOS 16.2, *) {
            let status = (manager as LiveActivityManager).getActivityStatus(
                activityId: args["activityId"] as? String ?? ""
            )
            result(status)
        }
    }

    // MARK: - v1.0.2 Handlers

    private func handleUpdateProgress(args: [String: Any], result: @escaping FlutterResult) {
        // iOS doesn't have native progress bar in notifications.
        // Update the notification body with progress text.
        guard let id = args["id"] as? Int else {
            result(false)
            return
        }
        let progress = args["progress"] as? Double ?? 0
        let title = args["title"] as? String
        let percentage = Int(progress * 100)

        let content = UNMutableNotificationContent()
        content.title = title ?? "Downloading..."
        content.body = "\(percentage)% complete"
        if progress >= 1.0 {
            content.body = "Complete"
        }

        let request = UNNotificationRequest(
            identifier: String(id), content: content, trigger: nil
        )
        center.add(request) { _ in
            result(true)
        }
    }

    private func handleSetMediaPlaybackState(args: [String: Any], result: @escaping FlutterResult) {
        let isPlaying = args["isPlaying"] as? Bool ?? false
        let positionMs = args["positionMs"] as? Int
        mediaSessionHelper.updatePlaybackState(
            isPlaying: isPlaying,
            positionMs: positionMs
        )
        result(true)
    }

    private func handleHasCriticalAlertEntitlement(result: @escaping FlutterResult) {
        criticalAlertHelper.checkEntitlement { hasEntitlement in
            result(hasEntitlement)
        }
    }

    // MARK: - Call Handlers

    /// Returns or creates the shared CallKitManager instance, wiring up
    /// call lifecycle callbacks to forward events to Flutter.
    private func getOrCreateCallKitManager() -> CallKitManager {
        if let existing = callKitManager {
            return existing
        }

        let manager = CallKitManager()

        manager.onCallAccepted = { [weak self] callId, callerName, callerNumber, extra in
            var args: [String: Any] = [
                "event": "callAccepted",
                "callId": callId,
            ]
            if let name = callerName { args["callerName"] = name }
            if let number = callerNumber { args["callerNumber"] = number }
            if let extra = extra { args["extra"] = extra }
            self?.channel?.invokeMethod("onCallEvent", arguments: args)
        }

        manager.onCallDeclined = { [weak self] callId in
            self?.channel?.invokeMethod("onCallEvent", arguments: [
                "event": "callDeclined",
                "callId": callId,
            ])
        }

        manager.onCallEnded = { [weak self] callId, reason in
            self?.channel?.invokeMethod("onCallEvent", arguments: [
                "event": "callEnded",
                "callId": callId,
                "reason": reason,
            ])
        }

        manager.onCallMuted = { [weak self] callId, isMuted in
            self?.channel?.invokeMethod("onCallEvent", arguments: [
                "event": "callMuted",
                "callId": callId,
                "isMuted": isMuted,
            ])
        }

        manager.onCallHeld = { [weak self] callId, isOnHold in
            self?.channel?.invokeMethod("onCallEvent", arguments: [
                "event": "callHeld",
                "callId": callId,
                "isOnHold": isOnHold,
            ])
        }

        callKitManager = manager
        return manager
    }

    private func handleShowIncomingCall(args: [String: Any], result: @escaping FlutterResult) {
        let callId = args["callId"] as? String ?? UUID().uuidString
        let callerName = args["callerName"] as? String
        let callerNumber = args["callerNumber"] as? String
        let callType = args["callType"] as? String ?? "audio"
        let hasVideo = args["hasVideo"] as? Bool ?? false
        let extra = args["extra"] as? [String: Any]

        // Use CallNotificationHelper as fallback in China
        guard CallNotificationHelper.isCallKitAvailable() else {
            callNotificationHelper.showIncomingCallNotification(
                callId: callId,
                callerName: callerName ?? "Unknown",
                callerNumber: callerNumber
            ) { success in
                result(success)
            }
            return
        }

        let manager = getOrCreateCallKitManager()
        manager.reportIncomingCall(
            callId: callId,
            callerName: callerName,
            callerNumber: callerNumber,
            callType: callType,
            hasVideo: hasVideo,
            extra: extra
        ) { success in
            if success {
                result(callId)
            } else {
                result(FlutterError(code: "CALL_ERROR", message: "Failed to report incoming call", details: nil))
            }
        }
    }

    private func handleShowOutgoingCall(args: [String: Any], result: @escaping FlutterResult) {
        let callId = args["callId"] as? String ?? UUID().uuidString
        let callerName = args["callerName"] as? String
        let callerNumber = args["callerNumber"] as? String
        let callType = args["callType"] as? String ?? "audio"

        guard CallNotificationHelper.isCallKitAvailable() else {
            // No outgoing call UI for non-CallKit regions; return success
            result(callId)
            return
        }

        let manager = getOrCreateCallKitManager()
        manager.startOutgoingCall(
            callId: callId,
            callerName: callerName,
            callerNumber: callerNumber,
            callType: callType
        ) { success in
            if success {
                result(callId)
            } else {
                result(FlutterError(code: "CALL_ERROR", message: "Failed to start outgoing call", details: nil))
            }
        }
    }

    private func handleSetCallConnected(args: [String: Any], result: @escaping FlutterResult) {
        guard let callId = args["callId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "callId is required", details: nil))
            return
        }

        guard CallNotificationHelper.isCallKitAvailable() else {
            // Show ongoing notification as fallback
            let callerName = args["callerName"] as? String ?? "Call"
            callNotificationHelper.showOngoingCallNotification(
                callId: callId,
                callerName: callerName
            ) { success in
                result(success)
            }
            return
        }

        let manager = getOrCreateCallKitManager()
        manager.setCallConnected(callId: callId)
        result(true)
    }

    private func handleEndCall(args: [String: Any], result: @escaping FlutterResult) {
        guard let callId = args["callId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "callId is required", details: nil))
            return
        }

        guard CallNotificationHelper.isCallKitAvailable() else {
            callNotificationHelper.hideCallNotification(callId: callId)
            result(true)
            return
        }

        let manager = getOrCreateCallKitManager()
        manager.endCall(callId: callId) { success in
            result(success)
        }
    }

    private func handleShowMissedCall(args: [String: Any], result: @escaping FlutterResult) {
        let callId = args["callId"] as? String ?? UUID().uuidString
        let callerName = args["callerName"] as? String ?? "Unknown"
        let callerNumber = args["callerNumber"] as? String
        let time = args["time"] as? Int

        callNotificationHelper.showMissedCallNotification(
            callId: callId,
            callerName: callerName,
            callerNumber: callerNumber,
            time: time
        ) { success in
            if success {
                result(callId)
            } else {
                result(FlutterError(code: "NOTIFICATION_ERROR", message: "Failed to show missed call notification", details: nil))
            }
        }
    }

    private func handleGetActiveCalls(result: @escaping FlutterResult) {
        guard CallNotificationHelper.isCallKitAvailable(), let manager = callKitManager else {
            result([])
            return
        }
        result(manager.getActiveCalls())
    }

    private func handleHideIncomingCall(args: [String: Any], result: @escaping FlutterResult) {
        guard let callId = args["callId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "callId is required", details: nil))
            return
        }

        guard CallNotificationHelper.isCallKitAvailable() else {
            callNotificationHelper.hideCallNotification(callId: callId)
            result(true)
            return
        }

        let manager = getOrCreateCallKitManager()
        manager.hideIncomingCall(callId: callId)
        result(true)
    }

    private func handleRegisterVoIPPush(result: @escaping FlutterResult) {
        pushKitManager.onTokenUpdate = { [weak self] token in
            self?.channel?.invokeMethod("onCallEvent", arguments: [
                "event": "voipTokenUpdated",
                "token": token,
            ])
        }

        pushKitManager.onIncomingPush = { [weak self] payload, completion in
            guard let self = self else {
                completion()
                return
            }

            // Extract call data from VoIP push payload
            let callId = payload["callId"] as? String ?? UUID().uuidString
            let callerName = payload["callerName"] as? String
            let callerNumber = payload["callerNumber"] as? String
            let callType = payload["callType"] as? String ?? "audio"
            let hasVideo = payload["hasVideo"] as? Bool ?? false
            let extra = payload["extra"] as? [String: Any]

            // MUST report to CallKit before completion on iOS 13+
            if CallNotificationHelper.isCallKitAvailable() {
                let manager = self.getOrCreateCallKitManager()
                manager.reportIncomingCall(
                    callId: callId,
                    callerName: callerName,
                    callerNumber: callerNumber,
                    callType: callType,
                    hasVideo: hasVideo,
                    extra: extra
                ) { _ in
                    completion()
                }
            } else {
                self.callNotificationHelper.showIncomingCallNotification(
                    callId: callId,
                    callerName: callerName ?? "Unknown",
                    callerNumber: callerNumber
                ) { _ in
                    completion()
                }
            }

            // Notify Flutter
            self.channel?.invokeMethod("onCallEvent", arguments: [
                "event": "incomingPush",
                "payload": payload,
            ])
        }

        pushKitManager.register()
        result(true)
    }

    private func handleGetVoIPToken(result: @escaping FlutterResult) {
        result(pushKitManager.getVoIPToken())
    }

    private func handleIsCallKitAvailable(result: @escaping FlutterResult) {
        result(CallNotificationHelper.isCallKitAvailable())
    }

    // MARK: - Private Helpers

    /// Records a notification in the history store.
    private func recordHistory(args: [String: Any], id: Int) {
        let entry: [String: Any] = [
            "id": id,
            "title": args["title"] as? String ?? "",
            "body": args["body"] as? String ?? "",
            "channel": args["channelId"] as? String ?? "",
            "group": args["group"] as? String ?? "",
            "deepLink": args["deepLink"] as? String ?? "",
            "payload": args["payload"] as? [String: Any] ?? [:],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "status": 0, // delivered
            "isRead": false,
        ]
        historyStore.add(entry)
    }
}
