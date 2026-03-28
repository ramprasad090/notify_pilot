import Foundation

/// Data bridge between the Flutter app and Widget Extension via shared UserDefaults.
/// Writes attribute and state data to a shared App Group container so that the
/// widget extension can read and display Live Activity content.
@available(iOS 13.0, *)
class LiveActivityDataBridge {

    /// The App Group identifier used for shared UserDefaults.
    private let appGroupId: String

    /// The shared UserDefaults instance, or nil if the App Group is unavailable.
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupId)
    }

    /// Prefix for attribute keys in shared storage.
    private let attrPrefix = "attr_"

    /// Prefix for state keys in shared storage.
    private let statePrefix = "state_"

    // MARK: - Init

    /// Creates a new bridge with the given App Group identifier.
    ///
    /// - Parameter appGroupId: The App Group identifier (e.g., "group.com.example.app").
    init(appGroupId: String) {
        self.appGroupId = appGroupId
    }

    // MARK: - Write

    /// Writes attribute data to shared storage for the given activity ID.
    /// Each key is prefixed with "attr_" and the activity ID.
    func writeAttributes(_ attributes: [String: Any], forActivityId activityId: String) {
        guard let defaults = sharedDefaults else {
            NSLog("[NotifyPilot] LiveActivityDataBridge: Unable to access shared UserDefaults for group '\(appGroupId)'")
            return
        }

        for (key, value) in attributes {
            let storageKey = "\(attrPrefix)\(activityId)_\(key)"
            defaults.set(value, forKey: storageKey)
        }
        defaults.synchronize()
    }

    /// Writes state data to shared storage for the given activity ID.
    /// Each key is prefixed with "state_" and the activity ID.
    func writeState(_ state: [String: Any], forActivityId activityId: String) {
        guard let defaults = sharedDefaults else {
            NSLog("[NotifyPilot] LiveActivityDataBridge: Unable to access shared UserDefaults for group '\(appGroupId)'")
            return
        }

        for (key, value) in state {
            let storageKey = "\(statePrefix)\(activityId)_\(key)"
            defaults.set(value, forKey: storageKey)
        }
        defaults.synchronize()
    }

    // MARK: - Read

    /// Reads all attribute data for the given activity ID from shared storage.
    func readAttributes(forActivityId activityId: String) -> [String: Any] {
        guard let defaults = sharedDefaults else { return [:] }
        let dict = defaults.dictionaryRepresentation()
        let prefix = "\(attrPrefix)\(activityId)_"

        var result: [String: Any] = [:]
        for (key, value) in dict {
            if key.hasPrefix(prefix) {
                let cleanKey = String(key.dropFirst(prefix.count))
                result[cleanKey] = value
            }
        }
        return result
    }

    /// Reads all state data for the given activity ID from shared storage.
    func readState(forActivityId activityId: String) -> [String: Any] {
        guard let defaults = sharedDefaults else { return [:] }
        let dict = defaults.dictionaryRepresentation()
        let prefix = "\(statePrefix)\(activityId)_"

        var result: [String: Any] = [:]
        for (key, value) in dict {
            if key.hasPrefix(prefix) {
                let cleanKey = String(key.dropFirst(prefix.count))
                result[cleanKey] = value
            }
        }
        return result
    }

    // MARK: - Clear

    /// Clears all data (attributes and state) for the given activity ID.
    func clear(forActivityId activityId: String) {
        guard let defaults = sharedDefaults else { return }
        let dict = defaults.dictionaryRepresentation()
        let attrPfx = "\(attrPrefix)\(activityId)_"
        let statePfx = "\(statePrefix)\(activityId)_"

        for key in dict.keys {
            if key.hasPrefix(attrPfx) || key.hasPrefix(statePfx) {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.synchronize()
    }

    /// Clears all Live Activity data from shared storage.
    func clearAll() {
        guard let defaults = sharedDefaults else { return }
        let dict = defaults.dictionaryRepresentation()

        for key in dict.keys {
            if key.hasPrefix(attrPrefix) || key.hasPrefix(statePrefix) {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.synchronize()
    }
}
