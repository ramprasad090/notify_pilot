import Foundation
import UserNotifications
import Flutter

/// Provides fallback call notification support using local notifications.
/// This is used in regions where CallKit is unavailable (e.g., China),
/// displaying incoming, missed, and ongoing call notifications via
/// UNUserNotificationCenter instead of the native call UI.
@available(iOS 13.0, *)
class CallNotificationHelper {

    // MARK: - Constants

    private static let incomingCallCategoryId = "NOTIFY_PILOT_INCOMING_CALL"
    private static let missedCallCategoryId = "NOTIFY_PILOT_MISSED_CALL"
    private static let ongoingCallCategoryId = "NOTIFY_PILOT_ONGOING_CALL"

    private static let acceptActionId = "NOTIFY_PILOT_CALL_ACCEPT"
    private static let declineActionId = "NOTIFY_PILOT_CALL_DECLINE"
    private static let hangUpActionId = "NOTIFY_PILOT_CALL_HANGUP"
    private static let callBackActionId = "NOTIFY_PILOT_CALL_CALLBACK"

    private let center = UNUserNotificationCenter.current()

    // MARK: - Init

    init() {
        registerCategories()
        NSLog("[NotifyPilot] CallNotificationHelper: Initialized")
    }

    // MARK: - Incoming Call

    /// Shows an incoming call notification with Accept and Decline actions.
    ///
    /// - Parameters:
    ///   - callId: A unique identifier for the call.
    ///   - callerName: The display name of the caller.
    ///   - callerNumber: The phone number of the caller (optional).
    ///   - actions: Optional custom action titles. Defaults to "Accept" and "Decline".
    ///   - completion: Called with true on success, false on failure.
    func showIncomingCallNotification(
        callId: String,
        callerName: String,
        callerNumber: String? = nil,
        actions: [String: String]? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let content = UNMutableNotificationContent()
        content.title = callerName
        content.body = callerNumber ?? "Incoming Call"
        content.sound = UNNotificationSound.defaultCritical
        content.categoryIdentifier = CallNotificationHelper.incomingCallCategoryId
        content.userInfo = [
            "callId": callId,
            "callerName": callerName,
            "callerNumber": callerNumber ?? "",
            "type": "incoming",
        ]

        // Use custom action titles if provided
        if let actions = actions {
            registerIncomingCallCategory(
                acceptTitle: actions["accept"] ?? "Accept",
                declineTitle: actions["decline"] ?? "Decline"
            )
        }

        let request = UNNotificationRequest(
            identifier: "call_\(callId)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                NSLog("[NotifyPilot] CallNotificationHelper: Failed to show incoming call notification: \(error.localizedDescription)")
                completion(false)
            } else {
                NSLog("[NotifyPilot] CallNotificationHelper: Showed incoming call notification for '\(callerName)'")
                completion(true)
            }
        }
    }

    // MARK: - Missed Call

    /// Shows a missed call notification.
    ///
    /// - Parameters:
    ///   - callId: A unique identifier for the call.
    ///   - callerName: The display name of the caller.
    ///   - callerNumber: The phone number of the caller (optional).
    ///   - time: The time the call was missed (epoch milliseconds).
    ///   - actions: Optional custom action titles.
    ///   - completion: Called with true on success, false on failure.
    func showMissedCallNotification(
        callId: String,
        callerName: String,
        callerNumber: String? = nil,
        time: Int? = nil,
        actions: [String: String]? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Missed Call"

        if let number = callerNumber, !number.isEmpty {
            content.body = "\(callerName) (\(number))"
        } else {
            content.body = callerName
        }

        // Format the time if provided
        if let timeMs = time {
            let date = Date(timeIntervalSince1970: Double(timeMs) / 1000.0)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            content.subtitle = formatter.string(from: date)
        }

        content.sound = .default
        content.categoryIdentifier = CallNotificationHelper.missedCallCategoryId
        content.userInfo = [
            "callId": callId,
            "callerName": callerName,
            "callerNumber": callerNumber ?? "",
            "type": "missed",
        ]

        let request = UNNotificationRequest(
            identifier: "missed_call_\(callId)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                NSLog("[NotifyPilot] CallNotificationHelper: Failed to show missed call notification: \(error.localizedDescription)")
                completion(false)
            } else {
                NSLog("[NotifyPilot] CallNotificationHelper: Showed missed call notification for '\(callerName)'")
                completion(true)
            }
        }
    }

    // MARK: - Ongoing Call

    /// Shows an ongoing call notification with a Hang Up action.
    ///
    /// - Parameters:
    ///   - callId: A unique identifier for the call.
    ///   - callerName: The display name of the other party.
    ///   - duration: The current call duration string (e.g., "02:35").
    ///   - completion: Called with true on success, false on failure.
    func showOngoingCallNotification(
        callId: String,
        callerName: String,
        duration: String? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        let content = UNMutableNotificationContent()
        content.title = callerName
        content.body = duration ?? "Ongoing Call"
        content.categoryIdentifier = CallNotificationHelper.ongoingCallCategoryId
        content.userInfo = [
            "callId": callId,
            "callerName": callerName,
            "type": "ongoing",
        ]

        let request = UNNotificationRequest(
            identifier: "call_\(callId)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                NSLog("[NotifyPilot] CallNotificationHelper: Failed to show ongoing call notification: \(error.localizedDescription)")
                completion(false)
            } else {
                NSLog("[NotifyPilot] CallNotificationHelper: Showed ongoing call notification for '\(callerName)'")
                completion(true)
            }
        }
    }

    // MARK: - Hide / Remove

    /// Removes a call notification from the notification center.
    ///
    /// - Parameter callId: The identifier of the call notification to remove.
    func hideCallNotification(callId: String) {
        let identifiers = [
            "call_\(callId)",
            "missed_call_\(callId)",
        ]
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        NSLog("[NotifyPilot] CallNotificationHelper: Removed notification for call '\(callId)'")
    }

    // MARK: - Region Check

    /// Returns whether CallKit is available on the current device.
    /// CallKit is unavailable in China (region code "CN").
    ///
    /// - Returns: false if the device region is China, true otherwise.
    static func isCallKitAvailable() -> Bool {
        let regionCode: String?
        if #available(iOS 16.0, *) {
            regionCode = Locale.current.region?.identifier
        } else {
            regionCode = Locale.current.regionCode
        }

        let isChinaRegion = regionCode?.uppercased() == "CN"

        if isChinaRegion {
            NSLog("[NotifyPilot] CallNotificationHelper: CallKit unavailable (China region)")
        }

        return !isChinaRegion
    }

    // MARK: - Private

    /// Registers the default notification categories for call actions.
    private func registerCategories() {
        let acceptAction = UNNotificationAction(
            identifier: CallNotificationHelper.acceptActionId,
            title: "Accept",
            options: [.foreground]
        )
        let declineAction = UNNotificationAction(
            identifier: CallNotificationHelper.declineActionId,
            title: "Decline",
            options: [.destructive]
        )
        let hangUpAction = UNNotificationAction(
            identifier: CallNotificationHelper.hangUpActionId,
            title: "Hang Up",
            options: [.destructive]
        )
        let callBackAction = UNNotificationAction(
            identifier: CallNotificationHelper.callBackActionId,
            title: "Call Back",
            options: [.foreground]
        )

        let incomingCategory = UNNotificationCategory(
            identifier: CallNotificationHelper.incomingCallCategoryId,
            actions: [acceptAction, declineAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let missedCategory = UNNotificationCategory(
            identifier: CallNotificationHelper.missedCallCategoryId,
            actions: [callBackAction],
            intentIdentifiers: [],
            options: []
        )

        let ongoingCategory = UNNotificationCategory(
            identifier: CallNotificationHelper.ongoingCallCategoryId,
            actions: [hangUpAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([incomingCategory, missedCategory, ongoingCategory])
    }

    /// Registers an incoming call category with custom action titles.
    ///
    /// - Parameters:
    ///   - acceptTitle: The title for the accept action button.
    ///   - declineTitle: The title for the decline action button.
    private func registerIncomingCallCategory(acceptTitle: String, declineTitle: String) {
        let acceptAction = UNNotificationAction(
            identifier: CallNotificationHelper.acceptActionId,
            title: acceptTitle,
            options: [.foreground]
        )
        let declineAction = UNNotificationAction(
            identifier: CallNotificationHelper.declineActionId,
            title: declineTitle,
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: CallNotificationHelper.incomingCallCategoryId,
            actions: [acceptAction, declineAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Re-register with updated category (merges with existing)
        center.getNotificationCategories { [weak self] existingCategories in
            var categories = existingCategories.filter {
                $0.identifier != CallNotificationHelper.incomingCallCategoryId
            }
            categories.insert(category)
            self?.center.setNotificationCategories(categories)
        }
    }
}
