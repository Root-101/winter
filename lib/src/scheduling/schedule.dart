/// When a scheduled task runs: every so often ([Schedule.every]), on a cron expression
/// ([Schedule.cron]), or your own rule (implement [next]).
///
/// ```dart
/// Schedule.every(const Duration(minutes: 5));
/// Schedule.cron('0 3 * * *');          // every day at 03:00, local time
/// Schedule.cron('*/15 9-18 * * MON-FRI', utc: true);
/// ```
///
/// {@category Scheduling}
abstract class Schedule {
  /// A schedule of your own: implement [next]
  const Schedule();

  /// Every [interval], counted from the previous time it was due (not from when the previous run
  /// ended), so it doesn't drift. The first run is one [interval] after the scheduler starts.
  ///
  /// An [interval] of zero or less is an [ArgumentError].
  factory Schedule.every(Duration interval) = _IntervalSchedule;

  /// A cron expression of 5 fields: minute (0-59), hour (0-23), day of the month (1-31), month
  /// (1-12 or `JAN`-`DEC`) and day of the week (0-7 or `SUN`-`SAT`; 0 and 7 are Sunday).
  ///
  /// Each field is `*`, a value, a range (`1-5`), a step (`*/15`, `0-30/10`, `5/10`) or a list of
  /// them (`1,15,30`). The macros `@yearly` (`@annually`), `@monthly`, `@weekly`, `@daily`
  /// (`@midnight`) and `@hourly` are accepted too. When both days are restricted, a day matches if
  /// either matches (as in cron: `0 0 1 * MON` is the 1st and every Monday).
  ///
  /// The times are local, or UTC with [utc] (servers in containers usually run in UTC anyway).
  /// An invalid expression is a [FormatException] that says which field is wrong.
  factory Schedule.cron(String expression, {bool utc}) = CronSchedule.parse;

  /// The first time it's due strictly after [after], or null if it's never due again
  DateTime? next(DateTime after);
}

class _IntervalSchedule extends Schedule {
  final Duration interval;

  _IntervalSchedule(this.interval) {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'must be positive');
    }
  }

  @override
  DateTime next(DateTime after) => after.add(interval);

  @override
  String toString() => 'every $interval';
}

/// A cron expression (see [Schedule.cron]), parsed once.
///
/// {@category Scheduling}
class CronSchedule extends Schedule {
  /// The expression as it was given
  final String expression;

  /// Whether the times are UTC (or local)
  final bool utc;

  final List<bool> _minutes;
  final List<bool> _hours;
  final List<bool> _daysOfMonth;
  final List<bool> _months;
  final List<bool> _daysOfWeek;
  final bool _anyDayOfMonth;
  final bool _anyDayOfWeek;

  CronSchedule._(
    this.expression,
    this.utc,
    this._minutes,
    this._hours,
    this._daysOfMonth,
    this._months,
    this._daysOfWeek,
    this._anyDayOfMonth,
    this._anyDayOfWeek,
  );

  static const Map<String, String> _macros = {
    '@yearly': '0 0 1 1 *',
    '@annually': '0 0 1 1 *',
    '@monthly': '0 0 1 * *',
    '@weekly': '0 0 * * 0',
    '@daily': '0 0 * * *',
    '@midnight': '0 0 * * *',
    '@hourly': '0 * * * *',
  };

  static const List<String> _monthNames = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  static const List<String> _dayNames = [
    'SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', //
  ];

  /// Parses [expression] (see [Schedule.cron]): a [FormatException] if it's not valid
  factory CronSchedule.parse(String expression, {bool utc = false}) {
    final String trimmed = expression.trim();
    final List<String> fields = (_macros[trimmed.toLowerCase()] ?? trimmed)
        .split(RegExp(r'\s+'));
    if (fields.length != 5) {
      throw FormatException(
        'A cron expression has 5 fields (minute hour day month weekday), '
        'this one has ${fields.length}',
        expression,
      );
    }
    List<bool> field(
      int index,
      String name,
      int min,
      int max, [
      List<String> names = const [],
      int namesFrom = 0,
    ]) => _parseField(
      expression,
      fields[index],
      name,
      min,
      max,
      names,
      namesFrom,
    );

    final List<bool> daysOfWeek = field(4, 'day of the week', 0, 7, _dayNames);
    // 7 is Sunday too
    if (daysOfWeek[7]) daysOfWeek[0] = true;

    return CronSchedule._(
      expression,
      utc,
      field(0, 'minute', 0, 59),
      field(1, 'hour', 0, 23),
      field(2, 'day of the month', 1, 31),
      field(3, 'month', 1, 12, _monthNames, 1),
      daysOfWeek,
      fields[2].startsWith('*'),
      fields[4].startsWith('*'),
    );
  }

  /// The values of one field, as a table indexed by value (`table[30]` for the minute 30)
  static List<bool> _parseField(
    String expression,
    String text,
    String name,
    int min,
    int max,
    List<String> names,
    int namesFrom,
  ) {
    Never invalid(String reason) => throw FormatException(
      'Invalid cron expression: the $name $reason',
      expression,
    );

    int value(String part) {
      final int? number =
          int.tryParse(part) ??
          switch (names.indexOf(part.toUpperCase())) {
            -1 => null,
            final int index => index + namesFrom,
          };
      if (number == null) invalid('"$part" is not a number');
      if (number < min || number > max) {
        invalid('$number is out of $min-$max');
      }
      return number;
    }

    final List<bool> table = List.filled(max + 1, false);
    for (final String item in text.split(',')) {
      if (item.isEmpty) invalid('has an empty item in "$text"');
      final List<String> stepParts = item.split('/');
      if (stepParts.length > 2) invalid('"$item" has more than one /');
      final String range = stepParts.first;
      int step = 1;
      if (stepParts.length == 2) {
        step =
            int.tryParse(stepParts[1]) ??
            invalid('step "${stepParts[1]}" is not a number');
        if (step < 1) invalid('step must be at least 1');
      }

      final int from;
      final int to;
      if (range == '*') {
        (from, to) = (min, max);
      } else if (range.contains('-')) {
        final List<String> bounds = range.split('-');
        if (bounds.length != 2) invalid('"$range" is not a range');
        (from, to) = (value(bounds[0]), value(bounds[1]));
        if (from > to) invalid('range "$range" goes backwards');
      } else {
        from = value(range);
        // `5/10`: from 5 to the end, every 10
        to = stepParts.length == 2 ? max : from;
      }
      for (int i = from; i <= to; i += step) {
        table[i] = true;
      }
    }
    return table;
  }

  bool _dayMatches(int year, int month, int day) {
    final bool dayOfMonth = _daysOfMonth[day];
    // DateTime.weekday is 1 (Monday) to 7 (Sunday): % 7 gives cron's 0 for Sunday
    final bool dayOfWeek =
        _daysOfWeek[DateTime.utc(year, month, day).weekday % 7];
    if (_anyDayOfMonth) return dayOfWeek;
    if (_anyDayOfWeek) return dayOfMonth;
    return dayOfMonth || dayOfWeek;
  }

  DateTime _at(int year, int month, int day, int hour, int minute) => utc
      ? DateTime.utc(year, month, day, hour, minute)
      : DateTime(year, month, day, hour, minute);

  @override
  DateTime? next(DateTime after) {
    final DateTime from = utc ? after.toUtc() : after.toLocal();
    // The calendar is walked in UTC fields (no daylight saving gaps while counting), and the
    // result is built in the zone of the schedule
    DateTime cursor = DateTime.utc(
      from.year,
      from.month,
      from.day,
      from.hour,
      from.minute + 1,
    );
    // A day that never exists (`0 0 30 2 *`) is never due: give up after 8 years (a leap day
    // can take up to 8, from 2096 to 2104)
    final int lastYear = cursor.year + 8;
    while (cursor.year <= lastYear) {
      if (!_months[cursor.month]) {
        cursor = DateTime.utc(cursor.year, cursor.month + 1);
      } else if (!_dayMatches(cursor.year, cursor.month, cursor.day)) {
        cursor = DateTime.utc(cursor.year, cursor.month, cursor.day + 1);
      } else if (!_hours[cursor.hour]) {
        cursor = DateTime.utc(
          cursor.year,
          cursor.month,
          cursor.day,
          cursor.hour + 1,
        );
      } else if (!_minutes[cursor.minute]) {
        cursor = cursor.add(const Duration(minutes: 1));
      } else {
        final DateTime due = _at(
          cursor.year,
          cursor.month,
          cursor.day,
          cursor.hour,
          cursor.minute,
        );
        // A local time skipped or repeated by daylight saving can fall before [after]
        if (due.isAfter(after)) return due;
        cursor = cursor.add(const Duration(minutes: 1));
      }
    }
    return null;
  }

  @override
  String toString() => utc ? 'cron "$expression" (UTC)' : 'cron "$expression"';
}
