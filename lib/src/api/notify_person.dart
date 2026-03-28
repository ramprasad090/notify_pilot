import 'notify_icon.dart';

/// A person in a messaging-style notification.
class NotifyPerson {
  /// Display name.
  final String name;

  /// Person's avatar icon.
  final NotifyIcon? icon;

  /// Unique identifier for this person.
  final String? key;

  /// Contact URI (e.g., `tel:` or `mailto:`).
  final String? uri;

  /// Creates a person for messaging-style notifications.
  const NotifyPerson({
    required this.name,
    this.icon,
    this.key,
    this.uri,
  });

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap() => {
        'name': name,
        'icon': icon?.toMap(),
        'key': key,
        'uri': uri,
      };

  /// Deserializes from a platform channel map.
  factory NotifyPerson.fromMap(Map<String, dynamic> map) => NotifyPerson(
        name: map['name'] as String,
        key: map['key'] as String?,
        uri: map['uri'] as String?,
      );
}
