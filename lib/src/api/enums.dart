/// Notification channel importance level.
enum NotifyImportance {
  /// No importance — does not show in shade.
  none,

  /// Minimum importance — no sound, no vibration, no peek.
  min,

  /// Low importance — no sound, no vibration.
  low,

  /// Default importance.
  default_,

  /// High importance — makes sound, peeks.
  high,

  /// Maximum importance — makes sound, peeks, heads-up.
  max,
}

/// Notification display priority.
enum NotifyPriority {
  /// Minimum priority.
  min,

  /// Low priority.
  low,

  /// Default priority.
  default_,

  /// High priority.
  high,

  /// Maximum priority.
  max,
}

/// Notification permission status.
enum NotifyPermission {
  /// Permission has been granted.
  granted,

  /// Permission has been denied.
  denied,

  /// Permission has not been requested yet.
  notDetermined,

  /// Permission is permanently denied (settings must be opened).
  permanentlyDenied,

  /// Permission is provisional (iOS silent notifications).
  provisional,
}

/// Notification history entry status.
enum NotifyStatus {
  /// Notification was delivered.
  delivered,

  /// Notification was opened/tapped.
  opened,

  /// Notification was dismissed.
  dismissed,

  /// An action was taken on the notification.
  action,
}

/// Predefined repeat intervals for simple recurring notifications.
enum RepeatInterval {
  /// Every minute (for testing).
  everyMinute,

  /// Every hour.
  hourly,

  /// Every day.
  daily,

  /// Every week.
  weekly,
}

/// Grouping strategy for [NotifyInbox] widget.
enum NotifyGroupBy {
  /// Group by date.
  date,

  /// Group by notification channel.
  channel,

  /// Group by notification group key.
  group,
}
