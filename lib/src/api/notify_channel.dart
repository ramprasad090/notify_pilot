import 'enums.dart';

/// Channel type preset for special behavior.
enum ChannelType {
  /// Regular channel — respects DND and silent mode.
  regular,

  /// Alarm channel — bypasses DND, plays through alarm audio stream.
  alarm,

  /// Call channel — for VoIP/calling apps.
  call,

  /// Timer channel — for countdown timers.
  timer,

  /// Message channel — high importance for chat.
  message,

  /// Silent channel — no sound, no vibration.
  silent,
}

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

  /// The channel type preset (alarm, call, timer, etc.).
  final ChannelType channelType;

  /// Whether to loop the sound (for alarms/calls).
  final bool loopSound;

  /// Whether to show fullscreen intent (for alarms/calls).
  final bool fullscreenIntent;

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
    this.channelType = ChannelType.regular,
    this.loopSound = false,
    this.fullscreenIntent = false,
  });

  /// Creates an alarm channel that bypasses DND and plays through the alarm audio stream.
  ///
  /// Android: `USAGE_ALARM` + `setBypassDnd(true)` + `IMPORTANCE_HIGH`
  /// iOS: `.criticalAlert` if entitled, else `.timeSensitive`
  const factory NotifyChannel.alarm({
    required String id,
    required String name,
    String? description,
    String? sound,
    bool loopSound,
    List<int>? vibrationPattern,
    bool fullscreenIntent,
  }) = _AlarmChannel;

  /// Creates a call channel for VoIP/calling apps.
  ///
  /// Android: `USAGE_NOTIFICATION_RINGTONE` + `CATEGORY_CALL` + fullscreen intent
  /// iOS: `.criticalAlert` or `.timeSensitive` + `CATEGORY_INCOMING_CALL`
  const factory NotifyChannel.call({
    required String id,
    required String name,
    String? sound,
    bool loopSound,
    bool fullscreenIntent,
  }) = _CallChannel;

  /// Creates a timer channel for countdown timers.
  ///
  /// Android: `USAGE_ALARM` + `IMPORTANCE_HIGH`
  /// iOS: `.timeSensitive`
  const factory NotifyChannel.timer({
    required String id,
    required String name,
    String? sound,
  }) = _TimerChannel;

  /// Creates a message channel with high importance for chat.
  const factory NotifyChannel.message({
    required String id,
    required String name,
  }) = _MessageChannel;

  /// Creates a silent channel with no sound or vibration.
  const factory NotifyChannel.silent({
    required String id,
    required String name,
  }) = _SilentChannel;

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
        'channelType': channelType.name,
        'loopSound': loopSound,
        'fullscreenIntent': fullscreenIntent,
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
        channelType: ChannelType.values.firstWhere(
          (t) => t.name == (map['channelType'] as String? ?? 'regular'),
          orElse: () => ChannelType.regular,
        ),
        loopSound: map['loopSound'] as bool? ?? false,
        fullscreenIntent: map['fullscreenIntent'] as bool? ?? false,
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
    ChannelType? channelType,
    bool? loopSound,
    bool? fullscreenIntent,
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
        channelType: channelType ?? this.channelType,
        loopSound: loopSound ?? this.loopSound,
        fullscreenIntent: fullscreenIntent ?? this.fullscreenIntent,
      );
}

class _AlarmChannel extends NotifyChannel {
  const _AlarmChannel({
    required super.id,
    required super.name,
    super.description,
    super.sound,
    super.loopSound = false,
    super.vibrationPattern,
    super.fullscreenIntent = true,
  }) : super(
          importance: NotifyImportance.high,
          vibration: true,
          badge: true,
          channelType: ChannelType.alarm,
        );
}

class _CallChannel extends NotifyChannel {
  const _CallChannel({
    required super.id,
    required super.name,
    super.sound,
    super.loopSound = true,
    super.fullscreenIntent = true,
  }) : super(
          importance: NotifyImportance.high,
          vibration: true,
          badge: true,
          channelType: ChannelType.call,
        );
}

class _TimerChannel extends NotifyChannel {
  const _TimerChannel({
    required super.id,
    required super.name,
    super.sound,
  }) : super(
          importance: NotifyImportance.high,
          vibration: true,
          badge: true,
          channelType: ChannelType.timer,
        );
}

class _MessageChannel extends NotifyChannel {
  const _MessageChannel({
    required super.id,
    required super.name,
  }) : super(
          importance: NotifyImportance.high,
          vibration: true,
          badge: true,
          channelType: ChannelType.message,
        );
}

class _SilentChannel extends NotifyChannel {
  const _SilentChannel({
    required super.id,
    required super.name,
  }) : super(
          importance: NotifyImportance.low,
          vibration: false,
          badge: false,
          channelType: ChannelType.silent,
        );
}
