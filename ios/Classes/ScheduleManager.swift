import Foundation
import UserNotifications

/// Manages scheduling of notifications using UNCalendarNotificationTrigger
/// and UNTimeIntervalNotificationTrigger. Stores schedule metadata in UserDefaults.
@available(iOS 13.0, *)
class ScheduleManager {

    private let center = UNUserNotificationCenter.current()
    private let metadataKey = "dev.notify_pilot.schedules"
    private let defaults = UserDefaults.standard

    // MARK: - Calendar Trigger (scheduleAt)

    /// Creates a UNCalendarNotificationTrigger for an exact date/time.
    /// The `dateComponents` dictionary should contain: year, month, day, hour, minute, second.
    func createCalendarTrigger(from args: [String: Any]) -> UNCalendarNotificationTrigger? {
        guard let year = args["year"] as? Int,
              let month = args["month"] as? Int,
              let day = args["day"] as? Int,
              let hour = args["hour"] as? Int,
              let minute = args["minute"] as? Int else {
            return nil
        }

        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = args["second"] as? Int ?? 0

        return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
    }

    // MARK: - Time Interval Trigger (scheduleAfter)

    /// Creates a UNTimeIntervalNotificationTrigger for a delay in seconds.
    func createTimeIntervalTrigger(seconds: TimeInterval, repeats: Bool = false) -> UNTimeIntervalNotificationTrigger? {
        guard seconds > 0 else { return nil }
        return UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: repeats)
    }

    // MARK: - Cron Trigger

    /// Creates a UNCalendarNotificationTrigger from cron-like fields.
    /// Supports: minute, hour, dayOfMonth, month, weekday.
    /// Pass nil for wildcard (*) fields.
    func createCronTrigger(from args: [String: Any]) -> UNCalendarNotificationTrigger? {
        var dateComponents = DateComponents()

        if let minute = args["minute"] as? Int { dateComponents.minute = minute }
        if let hour = args["hour"] as? Int { dateComponents.hour = hour }
        if let day = args["dayOfMonth"] as? Int { dateComponents.day = day }
        if let month = args["month"] as? Int { dateComponents.month = month }
        if let weekday = args["weekday"] as? Int { dateComponents.weekday = weekday }

        return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
    }

    // MARK: - Schedule Notification

    /// Schedules a notification request with the given trigger and content.
    func schedule(identifier: String, content: UNMutableNotificationContent,
                  trigger: UNNotificationTrigger, completion: @escaping (Bool) -> Void) {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("[NotifyPilot] Schedule error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    // MARK: - Metadata Storage

    /// Saves schedule metadata (tag, cron expression, notification data) to UserDefaults.
    func saveMetadata(tag: String, data: [String: Any]) {
        var all = loadAllMetadata()
        all[tag] = data
        saveAllMetadata(all)
    }

    /// Removes schedule metadata for the given tag.
    func removeMetadata(tag: String) {
        var all = loadAllMetadata()
        all.removeValue(forKey: tag)
        saveAllMetadata(all)
    }

    /// Loads schedule metadata for the given tag.
    func loadMetadata(tag: String) -> [String: Any]? {
        let all = loadAllMetadata()
        return all[tag] as? [String: Any]
    }

    /// Returns all schedule metadata entries.
    func loadAllMetadata() -> [String: Any] {
        guard let data = defaults.data(forKey: metadataKey) else { return [:] }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any] ?? [:]
        } catch {
            return [:]
        }
    }

    /// Clears all schedule metadata.
    func clearAllMetadata() {
        defaults.removeObject(forKey: metadataKey)
    }

    // MARK: - Pending Requests

    /// Returns all pending notification requests as maps.
    func getPendingRequests(completion: @escaping ([[String: Any]]) -> Void) {
        center.getPendingNotificationRequests { requests in
            let result: [[String: Any]] = requests.map { request in
                var map: [String: Any] = [
                    "id": request.identifier,
                    "title": request.content.title,
                    "body": request.content.body,
                ]
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    map["triggerType"] = "calendar"
                    if let nextDate = trigger.nextTriggerDate() {
                        map["nextTriggerDate"] = Int(nextDate.timeIntervalSince1970 * 1000)
                    }
                } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    map["triggerType"] = "interval"
                    map["timeInterval"] = trigger.timeInterval
                }
                map["userInfo"] = request.content.userInfo
                return map
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    // MARK: - Cancel

    /// Cancels a pending notification by identifier.
    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancels all pending notifications.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        clearAllMetadata()
    }

    // MARK: - Private

    private func saveAllMetadata(_ metadata: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: metadata, options: [])
            defaults.set(data, forKey: metadataKey)
        } catch {
            NSLog("[NotifyPilot] Failed to save schedule metadata: \(error.localizedDescription)")
        }
    }
}
