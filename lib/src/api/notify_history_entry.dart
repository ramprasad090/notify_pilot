import 'enums.dart';

/// Represents a notification history record.
class NotifyHistoryEntry {
  /// The notification ID.
  final int id;

  /// The notification title.
  final String title;

  /// The notification body.
  final String? body;

  /// The channel ID this notification was posted to.
  final String? channel;

  /// The group key.
  final String? group;

  /// The deep link associated with this notification.
  final String? deepLink;

  /// Custom payload data.
  final Map<String, dynamic>? payload;

  /// When the notification was created.
  final DateTime timestamp;

  /// Current status of the notification.
  final NotifyStatus status;

  /// The action ID if an action was taken.
  final String? actionTaken;

  /// Whether the user has read/acknowledged this notification.
  final bool isRead;

  /// Creates a history entry.
  const NotifyHistoryEntry({
    required this.id,
    required this.title,
    this.body,
    this.channel,
    this.group,
    this.deepLink,
    this.payload,
    required this.timestamp,
    this.status = NotifyStatus.delivered,
    this.actionTaken,
    this.isRead = false,
  });

  /// Deserializes from a platform channel map.
  factory NotifyHistoryEntry.fromMap(Map<String, dynamic> map) =>
      NotifyHistoryEntry(
        id: map['id'] as int,
        title: map['title'] as String,
        body: map['body'] as String?,
        channel: map['channel'] as String?,
        group: map['group'] as String?,
        deepLink: map['deepLink'] as String?,
        payload: (map['payload'] as Map?)?.cast<String, dynamic>(),
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        status: NotifyStatus.values[map['status'] as int? ?? 0],
        actionTaken: map['actionTaken'] as String?,
        isRead: map['isRead'] as bool? ?? false,
      );

  /// Serializes to a map.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'channel': channel,
        'group': group,
        'deepLink': deepLink,
        'payload': payload,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status.index,
        'actionTaken': actionTaken,
        'isRead': isRead,
      };

  /// Creates a copy with the given fields replaced.
  NotifyHistoryEntry copyWith({
    int? id,
    String? title,
    String? body,
    String? channel,
    String? group,
    String? deepLink,
    Map<String, dynamic>? payload,
    DateTime? timestamp,
    NotifyStatus? status,
    String? actionTaken,
    bool? isRead,
  }) =>
      NotifyHistoryEntry(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        channel: channel ?? this.channel,
        group: group ?? this.group,
        deepLink: deepLink ?? this.deepLink,
        payload: payload ?? this.payload,
        timestamp: timestamp ?? this.timestamp,
        status: status ?? this.status,
        actionTaken: actionTaken ?? this.actionTaken,
        isRead: isRead ?? this.isRead,
      );
}
