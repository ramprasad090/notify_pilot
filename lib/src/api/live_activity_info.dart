/// Status of a Live Activity.
enum LiveActivityStatus {
  /// Currently showing on Lock Screen / Dynamic Island.
  active,

  /// Ended but may still be visible on Lock Screen.
  ended,

  /// User dismissed it from the Lock Screen.
  dismissed,

  /// Past stale date — system has dimmed it.
  stale,
}

/// Information about an active Live Activity.
class LiveActivityInfo {
  /// Unique activity identifier.
  final String id;

  /// Activity type identifier (maps to ActivityAttributes).
  final String type;

  /// Static attributes set at creation time.
  final Map<String, dynamic> attributes;

  /// Current dynamic state.
  final Map<String, dynamic> state;

  /// Current status of the activity.
  final LiveActivityStatus status;

  /// iOS push token for server-driven updates.
  final String? pushToken;

  /// When the activity was started.
  final DateTime startedAt;

  /// Creates a Live Activity info object.
  const LiveActivityInfo({
    required this.id,
    required this.type,
    required this.attributes,
    required this.state,
    required this.status,
    this.pushToken,
    required this.startedAt,
  });

  /// Deserializes from a platform channel map.
  factory LiveActivityInfo.fromMap(Map<String, dynamic> map) =>
      LiveActivityInfo(
        id: map['id'] as String,
        type: map['type'] as String,
        attributes:
            (map['attributes'] as Map?)?.cast<String, dynamic>() ?? {},
        state: (map['state'] as Map?)?.cast<String, dynamic>() ?? {},
        status: LiveActivityStatus.values.firstWhere(
          (s) => s.name == (map['status'] as String? ?? 'active'),
          orElse: () => LiveActivityStatus.active,
        ),
        pushToken: map['pushToken'] as String?,
        startedAt: map['startedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int)
            : DateTime.now(),
      );

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'attributes': attributes,
        'state': state,
        'status': status.name,
        'pushToken': pushToken,
        'startedAt': startedAt.millisecondsSinceEpoch,
      };
}
