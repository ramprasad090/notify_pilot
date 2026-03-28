/// Event emitted by a Live Activity during its lifecycle.
sealed class LiveActivityEvent {
  const LiveActivityEvent._();

  /// The Live Activity has started.
  const factory LiveActivityEvent.started() = LiveActivityStarted;

  /// The Live Activity state was updated.
  const factory LiveActivityEvent.updated({
    required Map<String, dynamic> state,
  }) = LiveActivityUpdated;

  /// The Live Activity has ended.
  const factory LiveActivityEvent.ended() = LiveActivityEnded;

  /// The user dismissed the Live Activity from the Lock Screen.
  const factory LiveActivityEvent.dismissed() = LiveActivityDismissed;

  /// The user tapped a deep link in the Live Activity.
  const factory LiveActivityEvent.urlOpened({required String url}) =
      LiveActivityUrlOpened;

  /// Deserializes from a platform channel map.
  factory LiveActivityEvent.fromMap(Map<String, dynamic> map) {
    final event = map['event'] as String;
    switch (event) {
      case 'started':
        return const LiveActivityEvent.started();
      case 'updated':
        final state =
            (map['state'] as Map?)?.cast<String, dynamic>() ?? {};
        return LiveActivityEvent.updated(state: state);
      case 'ended':
        return const LiveActivityEvent.ended();
      case 'dismissed':
        return const LiveActivityEvent.dismissed();
      case 'urlOpened':
        return LiveActivityEvent.urlOpened(
            url: map['url'] as String? ?? '');
      default:
        return const LiveActivityEvent.ended();
    }
  }
}

/// The Live Activity has started.
final class LiveActivityStarted extends LiveActivityEvent {
  const LiveActivityStarted() : super._();
}

/// The Live Activity state was updated.
final class LiveActivityUpdated extends LiveActivityEvent {
  /// The updated dynamic state.
  final Map<String, dynamic> state;

  const LiveActivityUpdated({required this.state}) : super._();
}

/// The Live Activity has ended.
final class LiveActivityEnded extends LiveActivityEvent {
  const LiveActivityEnded() : super._();
}

/// The user dismissed the Live Activity.
final class LiveActivityDismissed extends LiveActivityEvent {
  const LiveActivityDismissed() : super._();
}

/// The user tapped a deep link in the Live Activity.
final class LiveActivityUrlOpened extends LiveActivityEvent {
  /// The URL that was opened.
  final String url;

  const LiveActivityUrlOpened({required this.url}) : super._();
}
