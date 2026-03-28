import Foundation
import UserNotifications

/// Handles notification permission requests and status queries.
@available(iOS 13.0, *)
class PermissionHelper {

    private let center = UNUserNotificationCenter.current()

    /// Requests notification authorization from the user.
    /// Returns `true` if permission was granted.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                NSLog("[NotifyPilot] Permission request error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Returns the current authorization status as a string.
    /// Possible values: "granted", "denied", "notDetermined", "provisional", "ephemeral".
    func getPermissionStatus(completion: @escaping (String) -> Void) {
        center.getNotificationSettings { settings in
            let status: String
            switch settings.authorizationStatus {
            case .authorized:
                status = "granted"
            case .denied:
                status = "denied"
            case .notDetermined:
                status = "notDetermined"
            case .provisional:
                status = "provisional"
            case .ephemeral:
                status = "ephemeral"
            @unknown default:
                status = "notDetermined"
            }
            DispatchQueue.main.async {
                completion(status)
            }
        }
    }
}
