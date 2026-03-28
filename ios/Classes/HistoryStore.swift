import Foundation

/// UserDefaults-based JSON storage for notification history.
@available(iOS 13.0, *)
class HistoryStore {

    private let storageKey = "dev.notify_pilot.history"
    private let defaults = UserDefaults.standard

    // MARK: - Add

    /// Adds a notification entry to the history store.
    func add(_ entry: [String: Any]) {
        var entries = loadAll()
        entries.append(entry)
        save(entries)
    }

    // MARK: - Query

    /// Queries history entries with optional filtering.
    /// Supports "limit", "group", and "channel" filters.
    func query(_ params: [String: Any]?) -> [[String: Any]] {
        var entries = loadAll()

        if let group = params?["group"] as? String {
            entries = entries.filter { ($0["group"] as? String) == group }
        }

        if let channel = params?["channel"] as? String {
            entries = entries.filter { ($0["channel"] as? String) == channel }
        }

        // Sort by timestamp descending (newest first)
        entries.sort { lhs, rhs in
            let lTime = lhs["timestamp"] as? Int ?? 0
            let rTime = rhs["timestamp"] as? Int ?? 0
            return lTime > rTime
        }

        if let limit = params?["limit"] as? Int, limit > 0 {
            entries = Array(entries.prefix(limit))
        }

        return entries
    }

    // MARK: - Update Status

    /// Updates the status field of a notification entry by ID.
    func updateStatus(id: Int, status: Int, actionTaken: String? = nil) {
        var entries = loadAll()
        if let index = entries.firstIndex(where: { ($0["id"] as? Int) == id }) {
            entries[index]["status"] = status
            if let action = actionTaken {
                entries[index]["actionTaken"] = action
            }
            save(entries)
        }
    }

    // MARK: - Mark Read

    /// Marks a single notification as read by ID.
    func markRead(id: Int) {
        var entries = loadAll()
        if let index = entries.firstIndex(where: { ($0["id"] as? Int) == id }) {
            entries[index]["isRead"] = true
            save(entries)
        }
    }

    /// Marks all notifications as read, optionally filtered by group.
    func markAllRead(group: String? = nil) {
        var entries = loadAll()
        for i in entries.indices {
            if let group = group {
                if (entries[i]["group"] as? String) == group {
                    entries[i]["isRead"] = true
                }
            } else {
                entries[i]["isRead"] = true
            }
        }
        save(entries)
    }

    // MARK: - Clear

    /// Clears all history entries.
    func clearAll() {
        save([])
    }

    /// Clears history entries older than the given number of milliseconds.
    func clearOlderThan(milliseconds: Int) {
        let cutoff = Int(Date().timeIntervalSince1970 * 1000) - milliseconds
        var entries = loadAll()
        entries.removeAll { entry in
            let timestamp = entry["timestamp"] as? Int ?? 0
            return timestamp < cutoff
        }
        save(entries)
    }

    // MARK: - Unread Count

    /// Returns the count of unread notifications, optionally filtered by group.
    func getUnreadCount(group: String? = nil) -> Int {
        let entries = loadAll()
        return entries.filter { entry in
            let isRead = entry["isRead"] as? Bool ?? false
            if isRead { return false }
            if let group = group {
                return (entry["group"] as? String) == group
            }
            return true
        }.count
    }

    // MARK: - Private

    private func loadAll() -> [[String: Any]] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [[String: Any]] ?? []
        } catch {
            NSLog("[NotifyPilot] Failed to load history: \(error.localizedDescription)")
            return []
        }
    }

    private func save(_ entries: [[String: Any]]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: entries, options: [])
            defaults.set(data, forKey: storageKey)
        } catch {
            NSLog("[NotifyPilot] Failed to save history: \(error.localizedDescription)")
        }
    }
}
