import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  /// The next [count] times of a UTC cron after [from]
  List<DateTime> nexts(String expression, DateTime from, [int count = 3]) {
    final Schedule schedule = Schedule.cron(expression, utc: true);
    final List<DateTime> result = [];
    DateTime? cursor = from;
    for (var i = 0; i < count; i++) {
      cursor = schedule.next(cursor!);
      if (cursor == null) break;
      result.add(cursor);
    }
    return result;
  }

  DateTime utc(int y, int mo, int d, [int h = 0, int mi = 0, int s = 0]) =>
      DateTime.utc(y, mo, d, h, mi, s);

  group('Schedule.every', () {
    test('is the interval after the previous time', () {
      final Schedule schedule = Schedule.every(const Duration(minutes: 5));

      expect(schedule.next(utc(2026, 1, 1, 10)), utc(2026, 1, 1, 10, 5));
      expect(schedule.toString(), contains('every'));
    });

    test('an interval of zero or less is an ArgumentError', () {
      expect(() => Schedule.every(Duration.zero), throwsArgumentError);
      expect(
        () => Schedule.every(const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });
  });

  group('Schedule.cron', () {
    final DateTime from = utc(2026, 10, 8, 10, 7, 30); // a Thursday

    test('every minute, strictly after the time given', () {
      expect(nexts('* * * * *', from), [
        utc(2026, 10, 8, 10, 8),
        utc(2026, 10, 8, 10, 9),
        utc(2026, 10, 8, 10, 10),
      ]);
      expect(
        nexts('* * * * *', utc(2026, 10, 8, 10, 7)).first,
        utc(2026, 10, 8, 10, 8),
      );
    });

    test('values, ranges, steps and lists', () {
      expect(nexts('0 3 * * *', from), [
        utc(2026, 10, 9, 3),
        utc(2026, 10, 10, 3),
        utc(2026, 10, 11, 3),
      ]);
      expect(nexts('*/15 * * * *', from), [
        utc(2026, 10, 8, 10, 15),
        utc(2026, 10, 8, 10, 30),
        utc(2026, 10, 8, 10, 45),
      ]);
      expect(nexts('0 9-11 * * *', from), [
        utc(2026, 10, 8, 11),
        utc(2026, 10, 9, 9),
        utc(2026, 10, 9, 10),
      ]);
      expect(nexts('5,50 10 * * *', from, 2), [
        utc(2026, 10, 8, 10, 50),
        utc(2026, 10, 9, 10, 5),
      ]);
      expect(nexts('0-30/10 10 * * *', from, 3), [
        utc(2026, 10, 8, 10, 10),
        utc(2026, 10, 8, 10, 20),
        utc(2026, 10, 8, 10, 30),
      ]);
      // 50/5: from 50 to the end
      expect(nexts('50/5 10 * * *', from, 3), [
        utc(2026, 10, 8, 10, 50),
        utc(2026, 10, 8, 10, 55),
        utc(2026, 10, 9, 10, 50),
      ]);
    });

    test('names of months and days, in any case', () {
      expect(nexts('0 0 * * mon-fri', from, 3), [
        utc(2026, 10, 9), // Friday
        utc(2026, 10, 12), // Monday
        utc(2026, 10, 13),
      ]);
      expect(nexts('0 0 1 JAN,Jul *', from, 2), [
        utc(2027, 1, 1),
        utc(2027, 7, 1),
      ]);
    });

    test('7 is Sunday, like 0', () {
      expect(nexts('0 0 * * 7', from, 1), [utc(2026, 10, 11)]);
      expect(nexts('0 0 * * 0', from, 1), [utc(2026, 10, 11)]);
    });

    test('both days restricted: either one matches', () {
      // The 13th, and every Monday
      expect(nexts('0 0 13 * 1', from, 3), [
        utc(2026, 10, 12),
        utc(2026, 10, 13),
        utc(2026, 10, 19),
      ]);
      // A field that starts with * (`*/10`) counts as "any", as in cron: only the Mondays
      expect(nexts('0 0 */10 * MON', from, 2), [
        utc(2026, 10, 12),
        utc(2026, 10, 19),
      ]);
    });

    test('the macros', () {
      expect(nexts('@hourly', from, 1), [utc(2026, 10, 8, 11)]);
      expect(nexts('@daily', from, 1), [utc(2026, 10, 9)]);
      expect(nexts('@midnight', from, 1), [utc(2026, 10, 9)]);
      expect(nexts('@weekly', from, 1), [utc(2026, 10, 11)]);
      expect(nexts('@monthly', from, 1), [utc(2026, 11, 1)]);
      expect(nexts('@yearly', from, 1), [utc(2027, 1, 1)]);
      expect(nexts('@annually', from, 1), [utc(2027, 1, 1)]);
    });

    test('the 31st skips the shorter months; the 29th of February waits for a leap year', () {
      expect(nexts('0 0 31 * *', from, 3), [
        utc(2026, 10, 31),
        utc(2026, 12, 31),
        utc(2027, 1, 31),
      ]);
      expect(nexts('0 0 29 2 *', from, 2), [
        utc(2028, 2, 29),
        utc(2032, 2, 29),
      ]);
    });

    test('a day that never exists is never due', () {
      expect(Schedule.cron('0 0 30 2 *', utc: true).next(from), isNull);
    });

    test('local time by default, and from any zone', () {
      final Schedule local = Schedule.cron('30 14 * * *');
      final DateTime next = local.next(DateTime(2026, 10, 8, 9))!;

      expect(next.isUtc, isFalse);
      expect((next.hour, next.minute), (14, 30));
      // A UTC time given to a local schedule
      expect(local.next(DateTime(2026, 10, 8, 9).toUtc()), next);
      expect(
        Schedule.cron(
          '0 0 * * *',
          utc: true,
        ).next(DateTime(2026, 10, 8))!.isUtc,
        isTrue,
      );
    });

    test('its description', () {
      expect(Schedule.cron('0 3 * * *').toString(), 'cron "0 3 * * *"');
      expect(
        Schedule.cron('0 3 * * *', utc: true).toString(),
        'cron "0 3 * * *" (UTC)',
      );
      expect(
        (Schedule.cron(' @daily ') as CronSchedule).expression,
        ' @daily ',
      );
    });

    test('an invalid expression says what is wrong', () {
      void invalid(String expression, String message) => expect(
        () => Schedule.cron(expression),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
        reason: expression,
      );

      invalid('* * * *', 'has 4');
      invalid('* * * * * *', 'has 6');
      invalid('60 * * * *', 'the minute 60 is out of 0-59');
      invalid('0 24 * * *', 'the hour 24 is out of 0-23');
      invalid('0 0 0 * *', 'the day of the month 0 is out of 1-31');
      invalid('0 0 * 13 *', 'the month 13 is out of 1-12');
      invalid('0 0 * * 8', 'the day of the week 8 is out of 0-7');
      invalid('x * * * *', 'the minute "x" is not a number');
      invalid('0 0 * FOO *', 'the month "FOO" is not a number');
      invalid('5-1 * * * *', 'range "5-1" goes backwards');
      invalid('1-2-3 * * * *', '"1-2-3" is not a range');
      invalid('*/0 * * * *', 'step must be at least 1');
      invalid('*/x * * * *', 'step "x" is not a number');
      invalid('*/2/3 * * * *', 'has more than one /');
      invalid('1,,2 * * * *', 'has an empty item');
    });
  });

  test('a schedule of your own', () {
    final Schedule once = _Once(utc(2027, 1, 1));

    expect(once.next(utc(2026, 1, 1)), utc(2027, 1, 1));
    expect(once.next(utc(2027, 1, 1)), isNull);
  });
}

class _Once extends Schedule {
  final DateTime at;

  const _Once(this.at);

  @override
  DateTime? next(DateTime after) => after.isBefore(at) ? at : null;
}
