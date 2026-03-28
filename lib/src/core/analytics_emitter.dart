import '../api/notify_analytics.dart';
import '../api/notify_history_entry.dart';

/// Fires analytics callbacks for notification lifecycle events.
class AnalyticsEmitter {
  NotifyAnalytics? _analytics;

  /// Configures the analytics callbacks.
  void initialize(NotifyAnalytics? analytics) {
    _analytics = analytics;
  }

  /// Emits a delivery event.
  void onDelivered(NotifyHistoryEntry entry) {
    _analytics?.onDelivered?.call(entry);
  }

  /// Emits an opened/tapped event.
  void onOpened(NotifyHistoryEntry entry) {
    _analytics?.onOpened?.call(entry);
  }

  /// Emits a dismissed event.
  void onDismissed(NotifyHistoryEntry entry) {
    _analytics?.onDismissed?.call(entry);
  }

  /// Emits an action-taken event.
  void onActionTaken(NotifyHistoryEntry entry, String actionId) {
    _analytics?.onActionTaken?.call(entry, actionId);
  }
}
