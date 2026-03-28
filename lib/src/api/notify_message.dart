import 'notify_image.dart';
import 'notify_person.dart';

/// A message in a messaging-style notification.
class NotifyMessage {
  /// Message text content.
  final String text;

  /// The sender. Null means current user.
  final NotifyPerson? sender;

  /// When the message was sent.
  final DateTime time;

  /// Optional image attached to the message.
  final NotifyImage? image;

  /// MIME type for non-text content.
  final String? mimeType;

  /// Creates a message for messaging-style notifications.
  const NotifyMessage({
    required this.text,
    this.sender,
    required this.time,
    this.image,
    this.mimeType,
  });

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap() => {
        'text': text,
        'sender': sender?.toMap(),
        'time': time.millisecondsSinceEpoch,
        'image': image?.toMap(),
        'mimeType': mimeType,
      };
}
