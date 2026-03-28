/// Event data received when a notification action button is tapped.
class NotifyActionEvent {
  /// The notification ID the action belongs to.
  final int? notificationId;

  /// The action identifier.
  final String actionId;

  /// Text input from inline reply action.
  final String? inputText;

  /// The deep link associated with the notification.
  final String? deepLink;

  /// Custom payload data.
  final Map<String, dynamic>? payload;

  /// Creates an action event.
  const NotifyActionEvent({
    this.notificationId,
    required this.actionId,
    this.inputText,
    this.deepLink,
    this.payload,
  });

  /// Deserializes from a platform channel map.
  factory NotifyActionEvent.fromMap(Map<String, dynamic> map) =>
      NotifyActionEvent(
        notificationId: map['notificationId'] as int?,
        actionId: map['actionId'] as String,
        inputText: map['inputText'] as String?,
        deepLink: map['deepLink'] as String?,
        payload: (map['payload'] as Map?)?.cast<String, dynamic>(),
      );

  /// Serializes to a map.
  Map<String, dynamic> toMap() => {
        'notificationId': notificationId,
        'actionId': actionId,
        'inputText': inputText,
        'deepLink': deepLink,
        'payload': payload,
      };
}
