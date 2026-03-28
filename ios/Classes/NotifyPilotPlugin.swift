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
            let (eventType, var eventData) = actionHandler.extractEvent(from: response)
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
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            self?.center.add(request) { error in
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
