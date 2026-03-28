import 'dart:ui' show Color;

import 'enums.dart';

/// Styling options for a notification.
class NotifyStyle {
  /// Accent color for the notification.
  final Color? color;

  /// Large icon URL or asset path.
  final String? largeIcon;

  /// Whether the notification is ongoing (cannot be swiped away).
  final bool ongoing;

  /// Whether to auto-cancel on tap.
  final bool autoCancel;

  /// Whether to show badge on app icon.
  final bool badge;

  /// Custom sound file name (without extension).
  final String? sound;

  /// Custom vibration pattern in milliseconds.
  final List<int>? vibration;

  /// Whether the notification is silent (no sound or vibration).
  final bool silent;

  /// Notification display priority.
  final NotifyPriority priority;

  /// Creates notification style options.
  const NotifyStyle({
    this.color,
    this.largeIcon,
    this.ongoing = false,
    this.autoCancel = true,
    this.badge = true,
    this.sound,
    this.vibration,
    this.silent = false,
    this.priority = NotifyPriority.default_,
  });

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap() => {
        'color': color?.toARGB32(),
        'largeIcon': largeIcon,
        'ongoing': ongoing,
        'autoCancel': autoCancel,
        'badge': badge,
        'sound': sound,
        'vibration': vibration,
        'silent': silent,
        'priority': priority.index,
      };

  /// Deserializes from a platform channel map.
  factory NotifyStyle.fromMap(Map<String, dynamic> map) => NotifyStyle(
        color: map['color'] != null ? Color(map['color'] as int) : null,
        largeIcon: map['largeIcon'] as String?,
        ongoing: map['ongoing'] as bool? ?? false,
        autoCancel: map['autoCancel'] as bool? ?? true,
        badge: map['badge'] as bool? ?? true,
        sound: map['sound'] as String?,
        vibration: (map['vibration'] as List?)?.cast<int>(),
        silent: map['silent'] as bool? ?? false,
        priority:
            NotifyPriority.values[map['priority'] as int? ?? 2],
      );
}
