import 'package:flutter_test/flutter_test.dart';
import 'package:notify_pilot/src/core/cron_parser.dart';
import 'package:notify_pilot/src/exceptions.dart';

void main() {
  group('CronParser', () {
    group('parsing', () {
      test('parses simple wildcard expression', () {
        final cron = CronParser.parse('* * * * *');
        expect(cron.expression, '* * * * *');
      });

      test('parses specific values', () {
        final cron = CronParser.parse('30 9 * * *');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 8, 0));
        expect(next, DateTime(2026, 3, 28, 9, 30));
      });

      test('parses step values', () {
        final cron = CronParser.parse('*/15 * * * *');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 10, 2));
        expect(next, DateTime(2026, 3, 28, 10, 15));
      });

      test('parses range values', () {
        final cron = CronParser.parse('0 9-17 * * *');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 18, 0));
        expect(next, DateTime(2026, 3, 29, 9, 0));
      });

      test('parses list values', () {
        final cron = CronParser.parse('0 9,12,18 * * *');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 10, 0));
        expect(next, DateTime(2026, 3, 28, 12, 0));
      });

      test('parses named days of week', () {
        final cron = CronParser.parse('0 10 * * MON');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 0, 0)); // Saturday
        // Next Monday is March 30, 2026
        expect(next, DateTime(2026, 3, 30, 10, 0));
      });

      test('parses named months', () {
        final cron = CronParser.parse('0 0 1 JAN *');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 0, 0));
        expect(next, DateTime(2027, 1, 1, 0, 0));
      });

      test('parses complex expression', () {
        // */2 means 0,2,4,6,8,10,12,14,16,18,20,22
        final cron = CronParser.parse('0 */2 * * *');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 7, 0));
        expect(next, DateTime(2026, 3, 28, 8, 0));
      });

      test('parses hour range with step', () {
        final cron = CronParser.parse('0 8-22/2 * * *');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 7, 0));
        expect(next, DateTime(2026, 3, 28, 8, 0));
      });

      test('parses step with range', () {
        final cron = CronParser.parse('0-30/10 * * * *');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 10, 5));
        expect(next, DateTime(2026, 3, 28, 10, 10));
      });

      test('handles day-of-week 7 as Sunday', () {
        final cron = CronParser.parse('0 10 * * 7');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 0, 0)); // Saturday
        // Next Sunday is March 29, 2026
        expect(next, DateTime(2026, 3, 29, 10, 0));
      });
    });

    group('nextAfter', () {
      test('returns next minute for every-minute cron', () {
        final cron = CronParser.parse('* * * * *');
        final from = DateTime(2026, 3, 28, 10, 30);
        final next = cron.nextAfter(from);
        expect(next, DateTime(2026, 3, 28, 10, 31));
      });

      test('wraps to next hour', () {
        final cron = CronParser.parse('0 * * * *');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 10, 30));
        expect(next, DateTime(2026, 3, 28, 11, 0));
      });

      test('wraps to next day', () {
        final cron = CronParser.parse('0 9 * * *');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 10, 0));
        expect(next, DateTime(2026, 3, 29, 9, 0));
      });

      test('wraps to next month', () {
        final cron = CronParser.parse('0 0 1 * *');
        final next = cron.nextAfter(DateTime(2026, 3, 15, 0, 0));
        expect(next, DateTime(2026, 4, 1, 0, 0));
      });

      test('wraps to next year', () {
        final cron = CronParser.parse('0 0 1 1 *');
        final next = cron.nextAfter(DateTime(2026, 6, 15, 0, 0));
        expect(next, DateTime(2027, 1, 1, 0, 0));
      });

      test('daily at 9am', () {
        final cron = CronParser.parse('0 9 * * *');
        final next = cron.nextAfter(DateTime(2026, 3, 28, 9, 0));
        // Already at 9:00, so next is tomorrow
        expect(next, DateTime(2026, 3, 29, 9, 0));
      });

      test('every Monday at 10am', () {
        final cron = CronParser.parse('0 10 * * MON');
        // March 28, 2026 is a Saturday
        final next = cron.nextAfter(DateTime(2026, 3, 28, 0, 0));
        expect(next!.weekday, DateTime.monday);
        expect(next.hour, 10);
        expect(next.minute, 0);
      });

      test('returns null for impossible expression', () {
        // February 31st will never happen
        final cron = CronParser.parse('0 0 31 2 *');
        final next = cron.nextAfter(DateTime(2026, 1, 1));
        expect(next, isNull);
      });
    });

    group('error handling', () {
      test('throws on wrong number of fields', () {
        expect(
          () => CronParser.parse('* * *'),
          throwsA(isA<NotifyCronParseException>()),
        );
      });

      test('throws on invalid value', () {
        expect(
          () => CronParser.parse('60 * * * *'),
          throwsA(isA<NotifyCronParseException>()),
        );
      });

      test('throws on invalid step', () {
        expect(
          () => CronParser.parse('*/0 * * * *'),
          throwsA(isA<NotifyCronParseException>()),
        );
      });

      test('throws on invalid range', () {
        expect(
          () => CronParser.parse('30-10 * * * *'),
          throwsA(isA<NotifyCronParseException>()),
        );
      });

      test('throws on invalid name', () {
        expect(
          () => CronParser.parse('* * * * INVALID'),
          throwsA(isA<NotifyCronParseException>()),
        );
      });
    });
  });
}
