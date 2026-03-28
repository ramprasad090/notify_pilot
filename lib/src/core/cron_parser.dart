import '../exceptions.dart';

/// Pure Dart cron expression parser.
///
/// Supports standard 5-field cron format:
/// ```
/// ┌───────────── minute (0-59)
/// │ ┌───────────── hour (0-23)
/// │ │ ┌───────────── day of month (1-31)
/// │ │ │ ┌───────────── month (1-12 or JAN-DEC)
/// │ │ │ │ ┌───────────── day of week (0-7 or SUN-SAT, 0 and 7 = Sunday)
/// * * * * *
/// ```
///
/// Supports: `*`, `*/n` (step), `n` (value), `n,m` (list), `n-m` (range),
/// day names (SUN-SAT), month names (JAN-DEC).
class CronParser {
  static const _dayNames = {
    'SUN': 0, 'MON': 1, 'TUE': 2, 'WED': 3,
    'THU': 4, 'FRI': 5, 'SAT': 6,
  };

  static const _monthNames = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
  };

  /// The parsed cron expression.
  final String expression;

  final Set<int> _minutes;
  final Set<int> _hours;
  final Set<int> _daysOfMonth;
  final Set<int> _months;
  final Set<int> _daysOfWeek;
  final bool _allDaysOfMonth;
  final bool _allDaysOfWeek;

  CronParser._({
    required this.expression,
    required Set<int> minutes,
    required Set<int> hours,
    required Set<int> daysOfMonth,
    required Set<int> months,
    required Set<int> daysOfWeek,
    required bool allDaysOfMonth,
    required bool allDaysOfWeek,
  })  : _minutes = minutes,
        _hours = hours,
        _daysOfMonth = daysOfMonth,
        _months = months,
        _daysOfWeek = daysOfWeek,
        _allDaysOfMonth = allDaysOfMonth,
        _allDaysOfWeek = allDaysOfWeek;

  /// Parses a cron expression string.
  ///
  /// Throws [NotifyCronParseException] if the expression is invalid.
  factory CronParser.parse(String expression) {
    final parts = expression.trim().split(RegExp(r'\s+'));
    if (parts.length != 5) {
      throw NotifyCronParseException(
          expression, 'Expected 5 fields, got ${parts.length}');
    }

    final allDom = parts[2] == '*';
    final allDow = parts[4] == '*';

    return CronParser._(
      expression: expression,
      minutes: _parseField(parts[0], 0, 59, expression),
      hours: _parseField(parts[1], 0, 23, expression),
      daysOfMonth: _parseField(parts[2], 1, 31, expression),
      months: _parseField(parts[3], 1, 12, expression, names: _monthNames),
      daysOfWeek: _normalizeDow(
          _parseField(parts[4], 0, 7, expression, names: _dayNames)),
      allDaysOfMonth: allDom,
      allDaysOfWeek: allDow,
    );
  }

  /// Normalize day-of-week: convert 7 (Sunday) to 0.
  static Set<int> _normalizeDow(Set<int> dow) {
    if (dow.contains(7)) {
      return {...dow.where((d) => d != 7), 0};
    }
    return dow;
  }

  /// Parse a single cron field into a set of valid integer values.
  static Set<int> _parseField(
    String field,
    int min,
    int max,
    String expression, {
    Map<String, int>? names,
  }) {
    final result = <int>{};

    for (final part in field.split(',')) {
      if (part == '*') {
        for (var i = min; i <= max; i++) {
          result.add(i);
        }
      } else if (part.contains('/')) {
        final segments = part.split('/');
        final step = int.tryParse(segments[1]);
        if (step == null || step <= 0) {
          throw NotifyCronParseException(
              expression, 'Invalid step value: ${segments[1]}');
        }

        int start;
        int end;
        if (segments[0] == '*') {
          start = min;
          end = max;
        } else if (segments[0].contains('-')) {
          final range = _parseRange(segments[0], min, max, expression, names);
          start = range.first;
          end = range.last;
        } else {
          start = _parseValue(segments[0], min, max, expression, names);
          end = max;
        }

        for (var i = start; i <= end; i += step) {
          result.add(i);
        }
      } else if (part.contains('-')) {
        final range = _parseRange(part, min, max, expression, names);
        for (var i = range.first; i <= range.last; i++) {
          result.add(i);
        }
      } else {
        result.add(_parseValue(part, min, max, expression, names));
      }
    }

    if (result.isEmpty) {
      throw NotifyCronParseException(
          expression, 'Field "$field" produced no values');
    }

    return result;
  }

  static ({int first, int last}) _parseRange(
    String range,
    int min,
    int max,
    String expression,
    Map<String, int>? names,
  ) {
    final parts = range.split('-');
    if (parts.length != 2) {
      throw NotifyCronParseException(
          expression, 'Invalid range: $range');
    }
    final first = _parseValue(parts[0], min, max, expression, names);
    final last = _parseValue(parts[1], min, max, expression, names);
    if (first > last) {
      throw NotifyCronParseException(
          expression, 'Invalid range: $first-$last');
    }
    return (first: first, last: last);
  }

  static int _parseValue(
    String value,
    int min,
    int max,
    String expression,
    Map<String, int>? names,
  ) {
    final upper = value.toUpperCase();
    if (names != null && names.containsKey(upper)) {
      return names[upper]!;
    }

    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw NotifyCronParseException(
          expression, 'Invalid value: $value');
    }
    if (parsed < min || parsed > max) {
      throw NotifyCronParseException(
          expression, 'Value $parsed out of range ($min-$max)');
    }
    return parsed;
  }

  /// Calculates the next occurrence after [from].
  ///
  /// Returns `null` if no valid occurrence can be found within 4 years
  /// (e.g., impossible day-of-month/day-of-week combination).
  DateTime? nextAfter(DateTime from) {
    var dt = DateTime(from.year, from.month, from.day, from.hour, from.minute)
        .add(const Duration(minutes: 1));

    // Safety limit: don't search more than 4 years ahead.
    final limit = from.add(const Duration(days: 1461));

    while (dt.isBefore(limit)) {
      // Check month
      if (!_months.contains(dt.month)) {
        // Advance to next valid month
        dt = _advanceToNextMonth(dt);
        continue;
      }

      // Check day-of-month and day-of-week
      if (!_matchesDay(dt)) {
        dt = DateTime(dt.year, dt.month, dt.day + 1);
        continue;
      }

      // Check hour
      if (!_hours.contains(dt.hour)) {
        dt = _advanceToNextHour(dt);
        continue;
      }

      // Check minute
      if (!_minutes.contains(dt.minute)) {
        final nextMinute = _nextInSet(_minutes, dt.minute);
        if (nextMinute != null) {
          dt = DateTime(dt.year, dt.month, dt.day, dt.hour, nextMinute);
        } else {
          dt = DateTime(dt.year, dt.month, dt.day, dt.hour + 1);
        }
        continue;
      }

      return dt;
    }

    return null;
  }

  /// Checks if a date matches the day constraints.
  ///
  /// Standard cron behavior: if both day-of-month and day-of-week are
  /// restricted (not `*`), the match is an OR (either must match).
  /// If only one is restricted, only that one must match.
  bool _matchesDay(DateTime dt) {
    final domMatch = _daysOfMonth.contains(dt.day);
    final dowMatch = _daysOfWeek.contains(dt.weekday % 7);

    if (_allDaysOfMonth && _allDaysOfWeek) return true;
    if (_allDaysOfMonth) return dowMatch;
    if (_allDaysOfWeek) return domMatch;
    // Both specified: OR logic (standard cron behavior)
    return domMatch || dowMatch;
  }

  DateTime _advanceToNextMonth(DateTime dt) {
    final nextMonth = _nextInSet(_months, dt.month);
    if (nextMonth != null) {
      return DateTime(dt.year, nextMonth, 1);
    }
    // Wrap to first valid month next year
    return DateTime(dt.year + 1, _months.reduce((a, b) => a < b ? a : b), 1);
  }

  DateTime _advanceToNextHour(DateTime dt) {
    final nextHour = _nextInSet(_hours, dt.hour);
    if (nextHour != null) {
      return DateTime(
          dt.year, dt.month, dt.day, nextHour, _minutes.reduce((a, b) => a < b ? a : b));
    }
    // Wrap to next day
    return DateTime(dt.year, dt.month, dt.day + 1, _hours.reduce((a, b) => a < b ? a : b),
        _minutes.reduce((a, b) => a < b ? a : b));
  }

  /// Returns the next value in [set] strictly greater than [current],
  /// or `null` if none exists.
  static int? _nextInSet(Set<int> set, int current) {
    int? best;
    for (final v in set) {
      if (v > current && (best == null || v < best)) {
        best = v;
      }
    }
    return best;
  }
}
