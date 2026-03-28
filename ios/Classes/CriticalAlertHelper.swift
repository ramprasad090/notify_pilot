import Foundation
import UserNotifications

/// Handles Critical Alert entitlement detection and sound configuration.
/// Falls back to time-sensitive interruption level when the Critical Alerts
/// entitlement is not available.
@available(iOS 13.0, *)
class CriticalAlertHelper {

    /// Shared singleton instance.
    static let shared = CriticalAlertHelper()

    /// Cached result of the entitlement check.
    private var _isCriticalAlertEntitled: Bool?

    init() {}

    // MARK: - Entitlement Detection

    /// Checks whether the app has the Critical Alerts entitlement.
    /// The result is cached after the first check.
    ///
    /// Detection is performed by checking notification settings for
    /// `criticalAlertSetting == .enabled`, which requires both the entitlement
    /// and user authorization.
    func isCriticalAlertEntitled(completion: @escaping (Bool) -> Void) {
        if let cached = _isCriticalAlertEntitled {
            completion(cached)
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let entitled = settings.criticalAlertSetting == .enabled
            self?._isCriticalAlertEntitled = entitled
            DispatchQueue.main.async {
                completion(entitled)
            }
        }
    }

    /// Alias for `isCriticalAlertEntitled(completion:)` used by the plugin.
    func checkEntitlement(completion: @escaping (Bool) -> Void) {
        isCriticalAlertEntitled(completion: completion)
    }

    /// Resets the cached entitlement state. Useful after permission changes.
    func resetCache() {
        _isCriticalAlertEntitled = nil
    }

    // MARK: - Sound Configuration

    /// Creates a critical alert sound with the given name and volume.
    /// Returns nil if the sound name is empty.
    ///
    /// - Parameters:
    ///   - name: The sound file name (without extension for system sounds).
    ///   - volume: The volume level from 0.0 to 1.0. Defaults to 1.0.
    /// - Returns: A critical notification sound.
    @available(iOS 12.0, *)
    func criticalSound(named name: String, volume: Float = 1.0) -> UNNotificationSound? {
        guard !name.isEmpty else { return nil }
        return UNNotificationSound.criticalSoundNamed(
            UNNotificationSoundName(name),
            withAudioVolume: volume
        )
    }

    /// Creates a default critical alert sound at the given volume.
    @available(iOS 12.0, *)
    func defaultCriticalSound(volume: Float = 1.0) -> UNNotificationSound {
        return UNNotificationSound.defaultCritical
    }

    // MARK: - Content Configuration

    /// Configures notification content for critical or high-priority delivery.
    ///
    /// If the app has the Critical Alerts entitlement, sets the sound to a critical sound.
    /// Otherwise, falls back to setting the interruption level to `.timeSensitive` on iOS 15+.
    ///
    /// - Parameters:
    ///   - content: The mutable notification content to configure.
    ///   - soundName: Optional custom sound name for critical alerts.
    ///   - volume: Sound volume for critical alerts (0.0 to 1.0).
    ///   - completion: Called with the configured content.
    func configureHighPriority(
        content: UNMutableNotificationContent,
        soundName: String? = nil,
        volume: Float = 1.0,
        completion: @escaping (UNMutableNotificationContent) -> Void
    ) {
        isCriticalAlertEntitled { entitled in
            if entitled {
                // Use critical alert sound
                if let name = soundName, !name.isEmpty {
                    if #available(iOS 12.0, *) {
                        content.sound = UNNotificationSound.criticalSoundNamed(
                            UNNotificationSoundName(name),
                            withAudioVolume: volume
                        )
                    }
                } else {
                    if #available(iOS 12.0, *) {
                        content.sound = UNNotificationSound.defaultCritical
                    }
                }
            } else {
                // Fall back to time-sensitive interruption level
                if #available(iOS 15.0, *) {
                    content.interruptionLevel = .timeSensitive
                }
                // Keep existing sound or set default
                if content.sound == nil {
                    content.sound = .default
                }
            }

            completion(content)
        }
    }

    // MARK: - Interruption Level

    /// Sets the interruption level on notification content.
    ///
    /// - Parameters:
    ///   - content: The mutable notification content.
    ///   - level: The level string: "passive", "active", "timeSensitive", or "critical".
    func setInterruptionLevel(on content: UNMutableNotificationContent, level: String) {
        if #available(iOS 15.0, *) {
            switch level {
            case "passive":
                content.interruptionLevel = .passive
            case "active":
                content.interruptionLevel = .active
            case "timeSensitive":
                content.interruptionLevel = .timeSensitive
            case "critical":
                content.interruptionLevel = .critical
            default:
                content.interruptionLevel = .active
            }
        }
    }
}
