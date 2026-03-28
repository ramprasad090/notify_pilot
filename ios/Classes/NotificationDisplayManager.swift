import Foundation
import UserNotifications

/// Creates UNMutableNotificationContent from Dart method call arguments.
/// Handles title, body, sound, badge, threading, categories, userInfo,
/// and image attachment downloads.
@available(iOS 13.0, *)
class NotificationDisplayManager {

    private let center = UNUserNotificationCenter.current()
    private let categoryManager: CategoryManager

    init(categoryManager: CategoryManager) {
        self.categoryManager = categoryManager
    }

    /// Builds a UNMutableNotificationContent from the given arguments map.
    ///
    /// Expected keys:
    /// - "id": Int notification ID
    /// - "title": String
    /// - "body": String?
    /// - "image": String? URL to download as attachment
    /// - "sound": String? custom sound name (from style)
    /// - "badge": Int?
    /// - "group": String? mapped to threadIdentifier
    /// - "channelId": String?
    /// - "deepLink": String?
    /// - "payload": [String: Any]?
    /// - "actions": [[String: Any]]?
    /// - "style": [String: Any]?
    func buildContent(from args: [String: Any], completion: @escaping (UNMutableNotificationContent) -> Void) {
        let content = UNMutableNotificationContent()

        // Title and body
        content.title = args["title"] as? String ?? ""
        if let body = args["body"] as? String {
            content.body = body
        }

        // Sound
        let style = args["style"] as? [String: Any]
        let silent = style?["silent"] as? Bool ?? false

        if silent {
            // No sound for silent notifications
        } else if let soundName = style?["sound"] as? String, !soundName.isEmpty {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        } else {
            content.sound = .default
        }

        // Badge
        if let badge = args["badge"] as? Int {
            content.badge = NSNumber(value: badge)
        } else if let styleBadge = style?["badge"] as? Bool, !styleBadge {
            // Do not set badge if explicitly disabled
        }

        // Thread identifier for grouping
        if let group = args["group"] as? String {
            content.threadIdentifier = group
        }

        // Store metadata in userInfo for retrieval on tap/action
        var userInfo: [String: Any] = [:]
        if let id = args["id"] as? Int {
            userInfo["notificationId"] = id
        }
        if let deepLink = args["deepLink"] as? String {
            userInfo["deepLink"] = deepLink
        }
        if let payload = args["payload"] as? [String: Any] {
            userInfo["payload"] = payload
        }
        if let channelId = args["channelId"] as? String {
            userInfo["channelId"] = channelId
        }
        if let group = args["group"] as? String {
            userInfo["group"] = group
        }
        // Store tag for cron reschedule identification
        if let tag = args["tag"] as? String {
            userInfo["tag"] = tag
        }
        content.userInfo = userInfo

        // Actions / category
        if let actions = args["actions"] as? [[String: Any]], !actions.isEmpty {
            let catId = categoryManager.categoryIdentifier(for: actions)
            categoryManager.registerCategory(identifier: catId, actions: actions)
            content.categoryIdentifier = catId
        }

        // Image attachment
        if let imageUrl = args["image"] as? String, let url = URL(string: imageUrl) {
            downloadImage(from: url) { attachment in
                if let attachment = attachment {
                    content.attachments = [attachment]
                }
                completion(content)
            }
        } else {
            completion(content)
        }
    }

    // MARK: - Private

    /// Downloads an image from a URL, saves to a temp file, and creates a UNNotificationAttachment.
    private func downloadImage(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            guard let localURL = localURL, error == nil else {
                NSLog("[NotifyPilot] Image download failed: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Determine file extension from response or URL
            let ext = self.fileExtension(from: response, url: url)
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + ext
            let destURL = tempDir.appendingPathComponent(fileName)

            do {
                // Move downloaded file to a location with proper extension
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: localURL, to: destURL)

                let attachment = try UNNotificationAttachment(
                    identifier: UUID().uuidString,
                    url: destURL,
                    options: nil
                )
                DispatchQueue.main.async { completion(attachment) }
            } catch {
                NSLog("[NotifyPilot] Attachment creation failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
        task.resume()
    }

    /// Determines the file extension for a downloaded image.
    private func fileExtension(from response: URLResponse?, url: URL) -> String {
        if let mimeType = response?.mimeType {
            switch mimeType {
            case "image/png": return ".png"
            case "image/jpeg": return ".jpg"
            case "image/gif": return ".gif"
            default: break
            }
        }

        let pathExt = url.pathExtension.lowercased()
        if !pathExt.isEmpty {
            return ".\(pathExt)"
        }

        return ".png"
    }
}
