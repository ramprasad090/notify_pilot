import Foundation

/// Manages push token registration and storage for Live Activities.
/// Converts raw APNs token data to hex strings and stores tokens per activity ID.
@available(iOS 13.0, *)
class PushTokenManager {

    /// Stored push tokens keyed by activity ID.
    private var tokens: [String: String] = [:]

    private let queue = DispatchQueue(label: "dev.notify_pilot.pushtoken", attributes: .concurrent)

    // MARK: - Token Conversion

    /// Converts raw APNs token Data to a lowercase hex string.
    static func hexString(from data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Storage

    /// Stores a push token for the given activity ID.
    func setToken(_ token: String, forActivityId activityId: String) {
        queue.async(flags: .barrier) {
            self.tokens[activityId] = token
        }
    }

    /// Returns the current push token for the given activity ID, if any.
    func getToken(forActivityId activityId: String) -> String? {
        var result: String?
        queue.sync {
            result = tokens[activityId]
        }
        return result
    }

    /// Removes the stored token for the given activity ID.
    func removeToken(forActivityId activityId: String) {
        queue.async(flags: .barrier) {
            self.tokens.removeValue(forKey: activityId)
        }
    }

    /// Returns all stored tokens as a dictionary of activity ID to token string.
    func allTokens() -> [String: String] {
        var result: [String: String] = [:]
        queue.sync {
            result = tokens
        }
        return result
    }

    /// Removes all stored tokens.
    func clearAll() {
        queue.async(flags: .barrier) {
            self.tokens.removeAll()
        }
    }
}
