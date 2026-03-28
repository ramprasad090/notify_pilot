import 'enums.dart';

/// Configuration for Android ongoing live notification.
class LiveNotificationConfig {
  /// Android notification channel ID.
  final String channelId;

  /// Android notification channel name.
  final String channelName;

  /// Custom RemoteViews XML layout name (without extension).
  ///
  /// Must correspond to a layout file in `res/layout/`.
  /// If null, the package provides a default layout.
  final String? layout;

  /// Small notification icon drawable resource name.
  final String? smallIcon;

  /// Whether the notification is ongoing (cannot be swiped away).
  final bool ongoing;

  /// Notification priority.
  final NotifyPriority priority;

  /// Accent color hex string (e.g., '#4CAF50').
  final String? color;

  /// Creates an Android live notification configuration.
  const LiveNotificationConfig({
    required this.channelId,
    required this.channelName,
    this.layout,
    this.smallIcon,
    this.ongoing = true,
    this.priority = NotifyPriority.high,
    this.color,
  });

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap() => {
        'channelId': channelId,
        'channelName': channelName,
        'layout': layout,
        'smallIcon': smallIcon,
        'ongoing': ongoing,
        'priority': priority.index,
        'color': color,
      };

  /// Deserializes from a platform channel map.
  factory LiveNotificationConfig.fromMap(Map<String, dynamic> map) =>
      LiveNotificationConfig(
        channelId: map['channelId'] as String,
        channelName: map['channelName'] as String,
        layout: map['layout'] as String?,
        smallIcon: map['smallIcon'] as String?,
        ongoing: map['ongoing'] as bool? ?? true,
        priority: NotifyPriority.values[map['priority'] as int? ?? 3],
        color: map['color'] as String?,
      );
}

/// Policy for how a Live Activity is dismissed after ending.
sealed class LiveDismissPolicy {
  const LiveDismissPolicy._();

  /// Remove the Live Activity instantly when ended.
  const factory LiveDismissPolicy.immediate() = _ImmediateDismiss;

  /// Keep the Live Activity on the Lock Screen for [duration] after ending.
  const factory LiveDismissPolicy.after(Duration duration) = _AfterDismiss;

  /// Let the system decide (up to 4 hours on iOS).
  const factory LiveDismissPolicy.default_() = _DefaultDismiss;

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap();
}

final class _ImmediateDismiss extends LiveDismissPolicy {
  const _ImmediateDismiss() : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'immediate'};
}

final class _AfterDismiss extends LiveDismissPolicy {
  final Duration duration;
  const _AfterDismiss(this.duration) : super._();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'after',
        'durationMs': duration.inMilliseconds,
      };
}

final class _DefaultDismiss extends LiveDismissPolicy {
  const _DefaultDismiss() : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'default'};
}

/// Configuration for Live Activity support during initialization.
class LiveActivityInitConfig {
  /// iOS App Group ID for data sharing between app and Widget Extension.
  final String appGroupId;

  /// URL scheme for deep links from Live Activity taps.
  final String? urlScheme;

  /// Creates a Live Activity initialization configuration.
  const LiveActivityInitConfig({
    required this.appGroupId,
    this.urlScheme,
  });

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap() => {
        'appGroupId': appGroupId,
        'urlScheme': urlScheme,
      };
}
