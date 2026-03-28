import '../api/history_config.dart';
import '../api/notify_history_entry.dart';
import '../platform/notify_pilot_platform.dart';

/// Manages notification history storage and retrieval.
///
/// Delegates persistence to the native platform (SQLite on Android,
/// UserDefaults on iOS). Provides query, unread count, mark-read,
/// and clear operations.
class HistoryManager {
  HistoryConfig _config = const HistoryConfig(enabled: false);

  /// Whether history tracking is enabled.
  bool get isEnabled => _config.enabled;

  /// Initializes with the given configuration.
  void initialize(HistoryConfig? config) {
    _config = config ?? const HistoryConfig(enabled: false);
  }

  /// Records a notification in history.
  Future<void> record(NotifyHistoryEntry entry) async {
    if (!_config.enabled) return;

    await NotifyPilotPlatform.instance.markRead({
      'action': 'addHistory',
      ...entry.toMap(),
      'maxEntries': _config.maxEntries,
    });
  }

  /// Queries notification history.
  Future<List<NotifyHistoryEntry>> getHistory({
    int? limit,
    String? group,
  }) async {
    if (!_config.enabled) return [];

    final results = await NotifyPilotPlatform.instance.getHistory({
      'limit': limit ?? _config.maxEntries,
      'group': group,
    });

    return results.map(NotifyHistoryEntry.fromMap).toList();
  }

  /// Returns the count of unread notifications.
  Future<int> getUnreadCount({String? group}) async {
    if (!_config.enabled) return 0;
    return NotifyPilotPlatform.instance.getUnreadCount(group);
  }

  /// Marks all notifications as read.
  Future<void> markAllRead() async {
    if (!_config.enabled) return;
    await NotifyPilotPlatform.instance.markRead({'all': true});
  }

  /// Marks a specific notification as read.
  Future<void> markRead({required int notificationId}) async {
    if (!_config.enabled) return;
    await NotifyPilotPlatform.instance
        .markRead({'notificationId': notificationId});
  }

  /// Clears notification history.
  Future<void> clearHistory({Duration? olderThan}) async {
    if (!_config.enabled) return;
    await NotifyPilotPlatform.instance.clearHistory(
      olderThan != null
          ? {'olderThanMillis': olderThan.inMilliseconds}
          : null,
    );
  }
}
