/// Type of phone call.
enum CallType {
  /// Audio-only call.
  audio,

  /// Video call.
  video,
}

/// State of an active call.
enum CallState {
  /// Incoming call ringing.
  ringing,

  /// Call is connecting.
  connecting,

  /// Call is connected and active.
  connected,

  /// Call is on hold.
  held,

  /// Call has ended.
  ended,
}

/// Information about an active call.
class CallInfo {
  /// Unique call identifier.
  final String callId;

  /// Caller display name.
  final String callerName;

  /// Caller phone number.
  final String? callerNumber;

  /// Call type (audio or video).
  final CallType callType;

  /// Current call state.
  final CallState state;

  /// When the call started.
  final DateTime startTime;

  /// Call duration (only set when connected or ended).
  final Duration? duration;

  /// Custom extra data.
  final Map<String, dynamic>? extra;

  const CallInfo({
    required this.callId,
    required this.callerName,
    this.callerNumber,
    required this.callType,
    required this.state,
    required this.startTime,
    this.duration,
    this.extra,
  });

  /// Deserializes from a platform channel map.
  factory CallInfo.fromMap(Map<String, dynamic> map) => CallInfo(
        callId: map['callId'] as String,
        callerName: map['callerName'] as String,
        callerNumber: map['callerNumber'] as String?,
        callType: CallType.values.firstWhere(
          (t) => t.name == (map['callType'] as String? ?? 'audio'),
          orElse: () => CallType.audio,
        ),
        state: CallState.values.firstWhere(
          (s) => s.name == (map['state'] as String? ?? 'ringing'),
          orElse: () => CallState.ringing,
        ),
        startTime: map['startTime'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int)
            : DateTime.now(),
        duration: map['durationMs'] != null
            ? Duration(milliseconds: map['durationMs'] as int)
            : null,
        extra: (map['extra'] as Map?)?.cast<String, dynamic>(),
      );

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap() => {
        'callId': callId,
        'callerName': callerName,
        'callerNumber': callerNumber,
        'callType': callType.name,
        'state': state.name,
        'startTime': startTime.millisecondsSinceEpoch,
        'durationMs': duration?.inMilliseconds,
        'extra': extra,
      };
}

/// Event emitted during a call's lifecycle.
sealed class CallEvent {
  const CallEvent._();

  /// Call was accepted by the user.
  const factory CallEvent.accepted({
    required String callId,
    Map<String, dynamic>? extra,
  }) = CallAccepted;

  /// Call was declined by the user.
  const factory CallEvent.declined({required String callId}) = CallDeclined;

  /// Call has ended.
  const factory CallEvent.ended({required String callId}) = CallEnded;

  /// Call mute state changed.
  const factory CallEvent.muted({
    required String callId,
    required bool muted,
  }) = CallMuted;

  /// Call hold state changed.
  const factory CallEvent.held({
    required String callId,
    required bool held,
  }) = CallHeld;

  /// Call timed out (no answer).
  const factory CallEvent.timeout({required String callId}) = CallTimeout;

  /// Speaker state changed.
  const factory CallEvent.speaker({
    required String callId,
    required bool speaker,
  }) = CallSpeaker;

  /// Deserializes from a platform channel map.
  factory CallEvent.fromMap(Map<String, dynamic> map) {
    final event = map['event'] as String;
    final callId = map['callId'] as String? ?? '';
    switch (event) {
      case 'accepted':
        return CallEvent.accepted(
          callId: callId,
          extra: (map['extra'] as Map?)?.cast<String, dynamic>(),
        );
      case 'declined':
        return CallEvent.declined(callId: callId);
      case 'ended':
        return CallEvent.ended(callId: callId);
      case 'muted':
        return CallEvent.muted(
            callId: callId, muted: map['muted'] as bool? ?? false);
      case 'held':
        return CallEvent.held(
            callId: callId, held: map['held'] as bool? ?? false);
      case 'timeout':
        return CallEvent.timeout(callId: callId);
      case 'speaker':
        return CallEvent.speaker(
            callId: callId, speaker: map['speaker'] as bool? ?? false);
      default:
        return CallEvent.ended(callId: callId);
    }
  }
}

/// Call was accepted.
final class CallAccepted extends CallEvent {
  final String callId;
  final Map<String, dynamic>? extra;
  const CallAccepted({required this.callId, this.extra}) : super._();
}

/// Call was declined.
final class CallDeclined extends CallEvent {
  final String callId;
  const CallDeclined({required this.callId}) : super._();
}

/// Call ended.
final class CallEnded extends CallEvent {
  final String callId;
  const CallEnded({required this.callId}) : super._();
}

/// Call mute toggled.
final class CallMuted extends CallEvent {
  final String callId;
  final bool muted;
  const CallMuted({required this.callId, required this.muted}) : super._();
}

/// Call hold toggled.
final class CallHeld extends CallEvent {
  final String callId;
  final bool held;
  const CallHeld({required this.callId, required this.held}) : super._();
}

/// Call timed out.
final class CallTimeout extends CallEvent {
  final String callId;
  const CallTimeout({required this.callId}) : super._();
}

/// Speaker toggled.
final class CallSpeaker extends CallEvent {
  final String callId;
  final bool speaker;
  const CallSpeaker({required this.callId, required this.speaker}) : super._();
}
