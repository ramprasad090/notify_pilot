/// Base exception for notify_pilot errors.
class NotifyPilotException implements Exception {
  /// Error message.
  final String message;

  /// Optional error code.
  final String? code;

  /// Creates a notify_pilot exception.
  const NotifyPilotException(this.message, {this.code});

  @override
  String toString() => 'NotifyPilotException($code): $message';
}

/// Thrown when notification permission is required but not granted.
class NotifyPermissionException extends NotifyPilotException {
  /// Creates a permission exception.
  const NotifyPermissionException(super.message)
      : super(code: 'PERMISSION_DENIED');
}

/// Thrown when scheduling a notification fails.
class NotifyScheduleException extends NotifyPilotException {
  /// Creates a schedule exception.
  const NotifyScheduleException(super.message)
      : super(code: 'SCHEDULE_ERROR');
}

/// Thrown when a cron expression cannot be parsed.
class NotifyCronParseException extends NotifyPilotException {
  /// The invalid cron expression.
  final String expression;

  /// Creates a cron parse exception.
  const NotifyCronParseException(this.expression, String message)
      : super(message, code: 'CRON_PARSE_ERROR');

  @override
  String toString() =>
      'NotifyCronParseException: $message (expression: "$expression")';
}
