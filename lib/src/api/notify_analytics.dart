import 'notify_history_entry.dart';

/// Analytics callback configuration for notification events.
class NotifyAnalytics {
  /// Called when a notification is delivered.
  final void Function(NotifyHistoryEntry notification)? onDelivered;

  /// Called when a notification is opened/tapped.
  final void Function(NotifyHistoryEntry notification)? onOpened;

  /// Called when a notification is dismissed.
  final void Function(NotifyHistoryEntry notification)? onDismissed;

  /// Called when an action is taken on a notification.
  final void Function(NotifyHistoryEntry notification, String actionId)?
      onActionTaken;

  /// Creates an analytics configuration.
  const NotifyAnalytics({
    this.onDelivered,
    this.onOpened,
    this.onDismissed,
    this.onActionTaken,
  });
}
