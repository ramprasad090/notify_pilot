/// Event data received when a notification is tapped.
class NotifyTapEvent {
  /// The notification ID that was tapped.
  final int? notificationId;

  /// The notification title.
  final String? title;

  /// The notification body.
  final String? body;

  /// The deep link associated with this notification.
  final String? deepLink;

  /// Custom payload data.
  final Map<String, dynamic>? payload;

  /// Whether this tap launched the app from a terminated state.
  final bool launchedApp;

  /// Creates a tap event.
  const NotifyTapEvent({
    this.notificationId,
    this.title,
    this.body,
    this.deepLink,
    this.payload,
    this.launchedApp = false,
  });

  /// Deserializes from a platform channel map.
  factory NotifyTapEvent.fromMap(Map<String, dynamic> map) => NotifyTapEvent(
        notificationId: map['notificationId'] as int?,
        title: map['title'] as String?,
        body: map['body'] as String?,
        deepLink: map['deepLink'] as String?,
        payload: (map['payload'] as Map?)?.cast<String, dynamic>(),
        launchedApp: map['launchedApp'] as bool? ?? false,
      );

  /// Serializes to a map.
  Map<String, dynamic> toMap() => {
        'notificationId': notificationId,
        'title': title,
        'body': body,
        'deepLink': deepLink,
        'payload': payload,
        'launchedApp': launchedApp,
      };
}
