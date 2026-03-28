import '../api/enums.dart';
import '../platform/notify_pilot_platform.dart';
import 'cron_parser.dart';
import 'id_generator.dart';
import 'timezone_resolver.dart';

/// Represents an active cron schedule.
class CronSchedule {
  /// Unique schedule tag.
  final String tag;

  /// The parsed cron expression.
  final CronParser cron;

  /// Notification title.
  final String title;

  /// Notification body.
  final String? body;

  /// The notification data to pass to platform.
  final Map<String, dynamic> notificationData;

  /// Creates a cron schedule.
  const CronSchedule({
    required this.tag,
    required this.cron,
    required this.title,
    this.body,
    required this.notificationData,
  });
}

/// Manages scheduled and cron-based notifications.
///
/// Coordinates cron parsing, timezone resolution, and platform scheduling.
/// For cron schedules, computes the next occurrence and delegates to native
/// exact alarms, then self-reschedules on fire.
class ScheduleManager {
  /// Active cron schedules indexed by tag.
  final Map<String, CronSchedule> _cronSchedules = {};

  /// All active cron schedules.
  List<CronSchedule> get activeSchedules => _cronSchedules.values.toList();

  /// Schedules a notification at an exact time.
  Future<int> scheduleAt(
    DateTime dateTime, {
    required String title,
    String? body,
    int? id,
    Map<String, dynamic> extra = const {},
  }) async {
    final notifId = id ?? IdGenerator.generate();
    final utcMillis = TimezoneResolver.toUtcMillis(dateTime);

    final data = <String, dynamic>{
      'id': notifId,
      'title': title,
      'body': body,
      'scheduledTime': utcMillis,
      ...extra,
    };

    await NotifyPilotPlatform.instance.scheduleAt(data);
    return notifId;
  }

  /// Schedules a notification after a delay.
  Future<int> scheduleAfter(
    Duration delay, {
    required String title,
    String? body,
    int? id,
    Map<String, dynamic> extra = const {},
  }) async {
    final notifId = id ?? IdGenerator.generate();

    final data = <String, dynamic>{
      'id': notifId,
      'title': title,
      'body': body,
      'delayMillis': delay.inMilliseconds,
      ...extra,
    };

    await NotifyPilotPlatform.instance.scheduleAfter(data);
    return notifId;
  }

  /// Schedules a cron-based recurring notification.
  ///
  /// Parses the cron expression, computes the next occurrence,
  /// and schedules it via the platform. On fire, [reschedule] should
  /// be called to schedule the next occurrence.
  Future<void> scheduleCron(
    String tag, {
    required String cron,
    required String title,
    String? body,
    Map<String, dynamic> extra = const {},
  }) async {
    final parser = CronParser.parse(cron);
    final next = parser.nextAfter(DateTime.now());

    if (next == null) return;

    final notificationData = <String, dynamic>{
      'title': title,
      'body': body,
      ...extra,
    };

    _cronSchedules[tag] = CronSchedule(
      tag: tag,
      cron: parser,
      title: title,
      body: body,
      notificationData: notificationData,
    );

    await _scheduleNextCron(tag, next);
  }

  /// Schedules a simple repeating notification.
  Future<void> scheduleRepeating(
    String tag, {
    required RepeatInterval interval,
    required String title,
    String? body,
    Map<String, dynamic> extra = const {},
  }) async {
    final cronExpr = switch (interval) {
      RepeatInterval.everyMinute => '* * * * *',
      RepeatInterval.hourly => '0 * * * *',
      RepeatInterval.daily => '0 0 * * *',
      RepeatInterval.weekly => '0 0 * * 0',
    };
    await scheduleCron(tag,
        cron: cronExpr, title: title, body: body, extra: extra);
  }

  /// Reschedules the next occurrence of a cron schedule after it fires.
  Future<void> reschedule(String tag) async {
    final schedule = _cronSchedules[tag];
    if (schedule == null) return;

    final next = schedule.cron.nextAfter(DateTime.now());
    if (next == null) {
      _cronSchedules.remove(tag);
      return;
    }

    await _scheduleNextCron(tag, next);
  }

  /// Cancels a scheduled notification by tag.
  Future<void> cancelSchedule(String tag) async {
    _cronSchedules.remove(tag);
    await NotifyPilotPlatform.instance.cancelSchedule(tag);
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAllSchedules() async {
    final tags = _cronSchedules.keys.toList();
    _cronSchedules.clear();
    for (final tag in tags) {
      await NotifyPilotPlatform.instance.cancelSchedule(tag);
    }
  }

  Future<void> _scheduleNextCron(String tag, DateTime next) async {
    final utcMillis = TimezoneResolver.toUtcMillis(next);
    final schedule = _cronSchedules[tag]!;

    await NotifyPilotPlatform.instance.scheduleCron({
      'tag': tag,
      'scheduledTime': utcMillis,
      ...schedule.notificationData,
    });
  }
}
