/// Manages notification grouping.
///
/// Tracks groups and generates summary notification IDs for
/// auto-stacking on Android and threading on iOS.
class GroupManager {
  /// Maps group keys to their summary notification IDs.
  final Map<String, int> _groupSummaryIds = {};

  /// Maps group keys to the set of notification IDs in that group.
  final Map<String, Set<int>> _groupNotifications = {};

  /// Returns the summary notification ID for a group.
  ///
  /// Creates a new summary ID if one doesn't exist for this group.
  int getSummaryId(String group) {
    return _groupSummaryIds.putIfAbsent(
        group, () => group.hashCode.abs() | 0x40000000);
  }

  /// Adds a notification ID to a group.
  void addToGroup(String group, int notificationId) {
    _groupNotifications.putIfAbsent(group, () => {}).add(notificationId);
  }

  /// Removes a notification ID from a group.
  void removeFromGroup(String group, int notificationId) {
    _groupNotifications[group]?.remove(notificationId);
    if (_groupNotifications[group]?.isEmpty ?? false) {
      _groupNotifications.remove(group);
      _groupSummaryIds.remove(group);
    }
  }

  /// Returns the number of notifications in a group.
  int groupCount(String group) {
    return _groupNotifications[group]?.length ?? 0;
  }

  /// Clears all group tracking data.
  void clear() {
    _groupSummaryIds.clear();
    _groupNotifications.clear();
  }
}
