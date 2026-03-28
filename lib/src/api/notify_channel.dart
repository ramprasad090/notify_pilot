import 'enums.dart';

/// Represents a notification channel (Android) or category configuration.
class NotifyChannel {
  /// Unique channel identifier.
  final String id;

  /// Human-readable channel name.
  final String name;

  /// Optional channel description.
  final String? description;

  /// Channel importance level.
  final NotifyImportance importance;

  /// Custom sound file name (without extension).
  final String? sound;

  /// Whether vibration is enabled.
  final bool vibration;

  /// Custom vibration pattern in milliseconds.
  final List<int>? vibrationPattern;

  /// Whether to show badge on app icon.
  final bool badge;

  /// Creates a notification channel.
  const NotifyChannel({
    required this.id,
    required this.name,
    this.description,
    this.importance = NotifyImportance.default_,
    this.sound,
    this.vibration = true,
    this.vibrationPattern,
    this.badge = true,
  });

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'importance': importance.index,
        'sound': sound,
        'vibration': vibration,
        'vibrationPattern': vibrationPattern,
        'badge': badge,
      };

  /// Deserializes from a platform channel map.
  factory NotifyChannel.fromMap(Map<String, dynamic> map) => NotifyChannel(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        importance: NotifyImportance.values[map['importance'] as int? ?? 3],
        sound: map['sound'] as String?,
        vibration: map['vibration'] as bool? ?? true,
        vibrationPattern: (map['vibrationPattern'] as List?)?.cast<int>(),
        badge: map['badge'] as bool? ?? true,
      );

  /// Creates a copy with the given fields replaced.
  NotifyChannel copyWith({
    String? id,
    String? name,
    String? description,
    NotifyImportance? importance,
    String? sound,
    bool? vibration,
    List<int>? vibrationPattern,
    bool? badge,
  }) =>
      NotifyChannel(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        importance: importance ?? this.importance,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        vibrationPattern: vibrationPattern ?? this.vibrationPattern,
        badge: badge ?? this.badge,
      );
}
