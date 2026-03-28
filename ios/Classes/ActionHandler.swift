import Foundation
import UserNotifications

/// Extracts action data from notification responses and formats event maps for Dart.
@available(iOS 13.0, *)
class ActionHandler {

    /// Extracts event data from a notification response.
    /// Returns a tuple of (eventType, eventData) suitable for sending to Dart.
    ///
    /// - For default tap action: returns ("onTap", tapEventData)
    /// - For dismiss action: returns ("onDismissed", dismissData)
    /// - For custom actions: returns ("onAction", actionEventData)
    func extractEvent(from response: UNNotificationResponse) -> (String, [String: Any]) {
        let content = response.notification.request.content
        let userInfo = content.userInfo

        let notificationId = userInfo["notificationId"] as? Int
        let title = content.title
        let body = content.body
        let deepLink = userInfo["deepLink"] as? String
        let payload = userInfo["payload"] as? [String: Any]

        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            let data: [String: Any?] = [
                "notificationId": notificationId,
                "title": title,
                "body": body,
                "deepLink": deepLink,
                "payload": payload,
                "launchedApp": false,
            ]
            return ("onTap", data.compactMapValues { $0 })

        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            let data: [String: Any?] = [
                "notificationId": notificationId,
            ]
            return ("onDismissed", data.compactMapValues { $0 })

        default:
            // Custom action button tapped
            var data: [String: Any?] = [
                "notificationId": notificationId,
                "actionId": actionIdentifier,
                "deepLink": deepLink,
                "payload": payload,
            ]

            // Check for text input response
            if let textResponse = response as? UNTextInputNotificationResponse {
                data["inputText"] = textResponse.userText
            }

            return ("onAction", data.compactMapValues { $0 })
        }
    }
}
