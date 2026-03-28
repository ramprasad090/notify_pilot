/// Resolves timezone information for notification scheduling.
///
/// Uses the device's local timezone offset to convert user-provided
/// [DateTime] objects to UTC milliseconds for native scheduling.
/// This eliminates the need for users to deal with TZDateTime or
/// import timezone packages.
class TimezoneResolver {
  /// Converts a local [DateTime] to UTC milliseconds since epoch.
  ///
  /// If [dateTime] is already UTC, it is used as-is.
  /// Otherwise, it is treated as local time.
  static int toUtcMillis(DateTime dateTime) {
    if (dateTime.isUtc) return dateTime.millisecondsSinceEpoch;
    return dateTime.toUtc().millisecondsSinceEpoch;
  }

  /// Converts UTC milliseconds since epoch to a local [DateTime].
  static DateTime fromUtcMillis(int millis) {
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
  }

  /// Returns the current local timezone offset as a [Duration].
  static Duration get localOffset => DateTime.now().timeZoneOffset;

  /// Returns the current local timezone name.
  static String get localTimezoneName => DateTime.now().timeZoneName;
}
