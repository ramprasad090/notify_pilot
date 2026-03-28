import Foundation
import UserNotifications

/// Creates UNMutableNotificationContent from Dart method call arguments.
/// Handles title, body, sound, badge, threading, categories, userInfo,
/// and image attachment downloads.
@available(iOS 13.0, *)
class NotificationDisplayManager {

    private let center = UNUserNotificationCenter.current()
    private let categoryManager: CategoryManager
    private let mediaDownloader = MediaDownloader.shared
    private let criticalAlertHelper = CriticalAlertHelper()

    init(categoryManager: CategoryManager) {
        self.categoryManager = categoryManager
    }

    /// Builds a UNMutableNotificationContent from the given arguments map.
    ///
    /// Expected keys:
    /// - "id": Int notification ID
    /// - "title": String
    /// - "body": String?
    /// - "image": String? URL to download as attachment (legacy)
    /// - "sound": [String: Any]? sound configuration map (v1.0.2)
    ///     - type: "none" | "default" | "custom" | "alarm" | "critical" | "systemAlarm"
    ///     - name: String? sound file name
    ///     - volume: Double? for critical sounds (0.0–1.0)
    /// - "badge": Int?
    /// - "group": String? mapped to threadIdentifier
    /// - "channelId": String?
    /// - "deepLink": String?
    /// - "payload": [String: Any]?
    /// - "actions": [[String: Any]]?
    /// - "style": [String: Any]? (legacy)
    /// - "displayStyle": [String: Any]? (v1.0.2)
    ///     - type: "bigText" | "bigPicture" | "inbox" | "progress"
    /// - "notifyImage": [String: Any]? image attachment map (v1.0.2)
    /// - "fullscreen": Bool?
    func buildContent(from args: [String: Any], completion: @escaping (UNMutableNotificationContent) -> Void) {
        let content = UNMutableNotificationContent()

        // Title and body
        content.title = args["title"] as? String ?? ""
        if let body = args["body"] as? String {
            content.body = body
        }

        // Sound (v1.0.2 map format takes priority over legacy style)
        let style = args["style"] as? [String: Any]
        let silent = style?["silent"] as? Bool ?? false

        if let soundMap = args["sound"] as? [String: Any],
           let soundType = soundMap["type"] as? String {
            // v1.0.2 sound parameter
            configureSoundFromMap(soundType: soundType, soundMap: soundMap, content: content) { configuredContent in
                self.buildContentAfterSound(args: args, style: style, content: configuredContent, completion: completion)
            }
            return
        } else if silent {
            // Legacy: no sound for silent notifications
        } else if let soundName = style?["sound"] as? String, !soundName.isEmpty {
            // Legacy: custom sound from style
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        } else {
            content.sound = .default
        }

        buildContentAfterSound(args: args, style: style, content: content, completion: completion)
    }

    // MARK: - Sound Configuration (v1.0.2)

    /// Configures notification sound from the v1.0.2 sound map.
    private func configureSoundFromMap(
        soundType: String,
        soundMap: [String: Any],
        content: UNMutableNotificationContent,
        completion: @escaping (UNMutableNotificationContent) -> Void
    ) {
        let soundName = soundMap["name"] as? String
        let volume = Float(soundMap["volume"] as? Double ?? 1.0)

        switch soundType {
        case "none":
            content.sound = nil
            completion(content)

        case "default":
            content.sound = .default
            completion(content)

        case "custom":
            if let name = soundName, !name.isEmpty {
                // Append .caf extension if not already present
                let fileName = name.hasSuffix(".caf") ? name : "\(name).caf"
                content.sound = UNNotificationSound(named: UNNotificationSoundName(fileName))
            } else {
                content.sound = .default
            }
            completion(content)

        case "alarm", "critical":
            // Use CriticalAlertHelper for alarm/critical sounds
            criticalAlertHelper.configureHighPriority(
                content: content,
                soundName: soundName,
                volume: volume
            ) { configuredContent in
                completion(configuredContent)
            }
            return

        case "systemAlarm":
            // Use default critical sound if entitled, otherwise fall back
            criticalAlertHelper.isCriticalAlertEntitled { entitled in
                if entitled {
                    if #available(iOS 12.0, *) {
                        content.sound = UNNotificationSound.defaultCritical
                    } else {
                        content.sound = .default
                    }
                } else {
                    if #available(iOS 15.0, *) {
                        content.interruptionLevel = .timeSensitive
                    }
                    content.sound = .default
                }
                completion(content)
            }
            return

        default:
            content.sound = .default
            completion(content)
        }
    }

    // MARK: - Content Building (continued after sound)

    /// Continues building notification content after sound has been configured.
    /// Handles badge, grouping, userInfo, actions, displayStyle, and image attachments.
    private func buildContentAfterSound(
        args: [String: Any],
        style: [String: Any]?,
        content: UNMutableNotificationContent,
        completion: @escaping (UNMutableNotificationContent) -> Void
    ) {
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

        // Process displayStyle (v1.0.2)
        if let displayStyle = args["displayStyle"] as? [String: Any],
           let dsType = displayStyle["type"] as? String {
            switch dsType {
            case "bigPicture":
                if let pictureMap = displayStyle["picture"] as? [String: Any],
                   let urlString = pictureMap["url"] as? String,
                   let url = URL(string: urlString) {
                    mediaDownloader.downloadAttachment(from: url) { attachment in
                        if let attachment = attachment {
                            content.attachments = [attachment]
                        }
                        completion(content)
                    }
                    return // async path - completion called above
                }
            case "bigText":
                // iOS shows full text naturally in expanded notification view
                if let bigText = displayStyle["bigText"] as? String {
                    content.body = bigText
                }
            case "inbox":
                if let lines = displayStyle["lines"] as? [String] {
                    content.body = lines.joined(separator: "\n")
                }
            case "progress":
                let progress = displayStyle["progress"] as? Double ?? 0
                let percentage = Int(progress * 100)
                if progress >= 1.0 {
                    content.body = "Complete"
                } else {
                    content.body = "\(percentage)% complete"
                }
            default:
                break
            }
        }

        // Process notifyImage (v1.0.2) - separate from displayStyle
        if let imageMap = args["notifyImage"] as? [String: Any],
           let urlString = imageMap["url"] as? String,
           let url = URL(string: urlString),
           content.attachments.isEmpty {
            mediaDownloader.downloadAttachment(from: url) { attachment in
                if let attachment = attachment {
                    content.attachments = [attachment]
                }
                self.finishBuildContent(args: args, content: content, completion: completion)
            }
            return // async path - completion called in finishBuildContent
        }

        // Legacy image attachment fallback
        finishBuildContent(args: args, content: content, completion: completion)
    }

    /// Final step: process legacy image URL and call completion.
    private func finishBuildContent(
        args: [String: Any],
        content: UNMutableNotificationContent,
        completion: @escaping (UNMutableNotificationContent) -> Void
    ) {
        // Legacy image attachment (only if no attachment already set by displayStyle/notifyImage)
        if content.attachments.isEmpty,
           let imageUrl = args["image"] as? String,
           let url = URL(string: imageUrl) {
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
