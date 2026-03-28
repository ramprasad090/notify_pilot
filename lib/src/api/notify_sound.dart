/// Sound configuration for a notification.
sealed class NotifySound {
  const NotifySound._();

  /// Custom sound from app resources.
  ///
  /// Android: `res/raw/{name}.mp3/.ogg/.wav`
  /// iOS: `{name}.caf/.wav/.aiff` in bundle
  const factory NotifySound.custom(String name, {bool loop}) =
      _CustomSound;

  /// Alarm sound — bypasses silent mode.
  ///
  /// Android: `AudioAttributes.USAGE_ALARM`
  /// iOS: `criticalSoundNamed` if entitled, else `timeSensitive`
  const factory NotifySound.alarm(String name) = _AlarmSound;

  /// Critical sound — bypasses DND and silent switch (iOS entitlement required).
  ///
  /// iOS: `criticalSoundNamed` with custom volume (0.0–1.0).
  /// Android: falls back to alarm sound at max volume.
  const factory NotifySound.critical(String name, {double volume}) =
      _CriticalSound;

  /// System default alarm sound (no custom file needed).
  const factory NotifySound.systemAlarm() = _SystemAlarmSound;

  /// System default notification sound.
  const factory NotifySound.default_() = _DefaultSound;

  /// No sound.
  const factory NotifySound.none() = _NoSound;

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap();
}

final class _CustomSound extends NotifySound {
  final String name;
  final bool loop;
  const _CustomSound(this.name, {this.loop = false}) : super._();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'custom',
        'name': name,
        'loop': loop,
      };
}

final class _AlarmSound extends NotifySound {
  final String name;
  const _AlarmSound(this.name) : super._();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'alarm',
        'name': name,
      };
}

final class _CriticalSound extends NotifySound {
  final String name;
  final double volume;
  const _CriticalSound(this.name, {this.volume = 1.0}) : super._();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'critical',
        'name': name,
        'volume': volume,
      };
}

final class _SystemAlarmSound extends NotifySound {
  const _SystemAlarmSound() : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'systemAlarm'};
}

final class _DefaultSound extends NotifySound {
  const _DefaultSound() : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'default'};
}

final class _NoSound extends NotifySound {
  const _NoSound() : super._();

  @override
  Map<String, dynamic> toMap() => {'type': 'none'};
}
