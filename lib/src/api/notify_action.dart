/// Trigger configuration for bg_orchestrator background tasks.
class BgTaskTrigger {
  /// Name of the background task to trigger.
  final String taskName;

  /// Input data to pass to the task.
  final Map<String, dynamic>? input;

  /// Creates a background task trigger.
  const BgTaskTrigger({
    required this.taskName,
    this.input,
  });

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap() => {
        'taskName': taskName,
        'input': input,
      };

  /// Deserializes from a platform channel map.
  factory BgTaskTrigger.fromMap(Map<String, dynamic> map) => BgTaskTrigger(
        taskName: map['taskName'] as String,
        input: (map['input'] as Map?)?.cast<String, dynamic>(),
      );
}

/// Represents a notification action button.
class NotifyAction {
  /// Unique action identifier.
  final String id;

  /// Button label displayed to the user.
  final String label;

  /// Whether this action shows an inline text input (e.g., reply).
  final bool input;

  /// Hint text for the inline input field.
  final String? inputHint;

  /// Whether this action is destructive (shown in red on iOS).
  final bool destructive;

  /// Whether tapping this action brings the app to foreground.
  final bool foreground;

  /// Optional bg_orchestrator task to trigger on action.
  final BgTaskTrigger? bgTask;

  /// Creates a notification action.
  const NotifyAction(
    this.id, {
    required this.label,
    this.input = false,
    this.inputHint,
    this.destructive = false,
    this.foreground = true,
    this.bgTask,
  });

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'input': input,
        'inputHint': inputHint,
        'destructive': destructive,
        'foreground': foreground,
        'bgTask': bgTask?.toMap(),
      };

  /// Deserializes from a platform channel map.
  factory NotifyAction.fromMap(Map<String, dynamic> map) => NotifyAction(
        map['id'] as String,
        label: map['label'] as String,
        input: map['input'] as bool? ?? false,
        inputHint: map['inputHint'] as String?,
        destructive: map['destructive'] as bool? ?? false,
        foreground: map['foreground'] as bool? ?? true,
        bgTask: map['bgTask'] != null
            ? BgTaskTrigger.fromMap(
                (map['bgTask'] as Map).cast<String, dynamic>())
            : null,
      );
}
