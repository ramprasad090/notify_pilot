/// Represents an incoming push notification message.
class PushMessage {
  /// The notification title.
  final String? title;

  /// The notification body.
  final String? body;

  /// URL to an image to display.
  final String? imageUrl;

  /// Custom data payload.
  final Map<String, String> data;

  /// Unique message identifier.
  final String? messageId;

  /// When the message was sent.
  final DateTime? sentTime;

  /// Creates a push message.
  const PushMessage({
    this.title,
    this.body,
    this.imageUrl,
    this.data = const {},
    this.messageId,
    this.sentTime,
  });

  /// Deserializes from a platform channel map.
  factory PushMessage.fromMap(Map<String, dynamic> map) => PushMessage(
        title: map['title'] as String?,
        body: map['body'] as String?,
        imageUrl: map['imageUrl'] as String?,
        data: (map['data'] as Map?)?.cast<String, String>() ?? const {},
        messageId: map['messageId'] as String?,
        sentTime: map['sentTime'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['sentTime'] as int)
            : null,
      );

  /// Serializes to a map.
  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'imageUrl': imageUrl,
        'data': data,
        'messageId': messageId,
        'sentTime': sentTime?.millisecondsSinceEpoch,
      };
}
