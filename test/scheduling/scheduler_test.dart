import 'dart:async';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

import 'fake_time.dart';

void main() {
  late FakeTime time;
  late List<String> logs;

  setUp(() {
    time = FakeTime(DateTime.utc(2026, 10, 8, 10, 0, 30));
    logs = [];
    Winter.context.setUp(logger: _MemoryLogger(logs));
    addTearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));
  });

  /// A scheduler on the fake clock, stopped at the end of the test
  Scheduler scheduler() {
    final Scheduler scheduler = Scheduler(clock: time.clock);
    addTearDown(scheduler.stop);
    return scheduler;
  }

  test('every: runs each interval, counted from when it was due', () async {
    await time.run(() async {
      final List<DateTime> runs = [];
      final Scheduler s = scheduler();
      final ScheduledTask task = s.every(
        const Duration(minutes: 5),
        name: 'purge',
        task: () => runs.add(time.now),
      );
      expect(task.nextRun, isNull, reason: 'not started');

      s.start();
      expect(s.isStarted, isTrue);
      expect(task.nextRun, DateTime.utc(2026, 10, 8, 10, 5, 30));
      expect(logs, contains('Scheduler started with 1 task(s)'));

      await time.advance(const Duration(minutes: 11));

      expect(runs, [
        DateTime.utc(2026, 10, 8, 10, 5, 30),
        DateTime.utc(2026, 10, 8, 10, 10, 30),
      ]);
      expect(task.lastRun, DateTime.utc(2026, 10, 8, 10, 10, 30));
      expect(task.lastSucceeded, DateTime.utc(2026, 10, 8, 10, 10, 30));
      expect(task.nextRun, DateTime.utc(2026, 10, 8, 10, 15, 30));
    });
  });

  test(
    'cron: a daily task, checking the time at least once a minute',
    () async {
      await time.run(() async {
        final List<DateTime> runs = [];
        final Scheduler s = scheduler()
          ..cron(
            '0 3 * * *',
            utc: true,
            name: 'report',
            task: () => runs.add(time.now),
          );
        s.start();

        // Never a timer of hours: one per minute at most
        await time.advance(const Duration(days: 2));

        expect(runs, [
          DateTime.utc(2026, 10, 9, 3),
          DateTime.utc(2026, 10, 10, 3),
        ]);
        expect(s['report']!.nextRun, DateTime.utc(2026, 10, 11, 3));
        expect(time.pendingTimers, 1);
      });
    },
  );

  test('a task that fails is logged and runs again the next time', () async {
    await time.run(() async {
      int calls = 0;
      final Scheduler s = scheduler();
      final ScheduledTask task = s.every(
        const Duration(minutes: 1),
        name: 'flaky',
        task: () async {
          calls++;
          if (calls == 1) throw StateError('database down');
        },
      );
      s.start();

      await time.advance(const Duration(minutes: 1));
      expect(logs, contains('The scheduled task "flaky" failed'));
      expect(task.lastRun, isNotNull);
      expect(task.lastSucceeded, isNull);

      await time.advance(const Duration(minutes: 1));
      expect(calls, 2);
      expect(task.lastSucceeded, time.now);
    });
  });

  test('a run due while the previous one runs is skipped', () async {
    await time.run(() async {
      final Completer<void> slow = Completer<void>();
      int calls = 0;
      final Scheduler s = scheduler();
      final ScheduledTask task = s.every(
        const Duration(minutes: 1),
        name: 'slow',
        task: () {
          calls++;
          return slow.future;
        },
      );
      s.start();

      await time.advance(const Duration(minutes: 3));
      expect(calls, 1);
      expect(task.isRunning, isTrue);
      expect(
        logs.where(
          (log) =>
              log.startsWith('Skipping a run of the scheduled task "slow"'),
        ),
        hasLength(2),
      );

      slow.complete();
      await FakeTime.flush();
      expect(task.isRunning, isFalse);
      await time.advance(const Duration(minutes: 1));
      expect(calls, 2);
    });
  });

  test('allowOverlap: a run starts even if the previous one runs', () async {
    await time.run(() async {
      final Completer<void> slow = Completer<void>();
      int calls = 0;
      final Scheduler s = scheduler()
        ..every(
          const Duration(minutes: 1),
          name: 'parallel',
          allowOverlap: true,
          task: () {
            calls++;
            return slow.future;
          },
        );
      s.start();

      await time.advance(const Duration(minutes: 3));
      expect(calls, 3);
      slow.complete();
    });
  });

  test(
    'runs missed while the machine was suspended are not repeated',
    () async {
      await time.run(() async {
        int calls = 0;
        final Scheduler s = scheduler();
        final ScheduledTask task = s.every(
          const Duration(minutes: 10),
          name: 'sync',
          task: () => calls++,
        );
        s.start();

        // Suspended for an hour: the timer fires late, once
        time.jump(const Duration(hours: 1));
        await time.advance(Duration.zero);
        await time.advance(const Duration(minutes: 1));

        expect(calls, 1);
        expect(logs, contains('The scheduled task "sync" missed 5 run(s)'));
        expect(task.nextRun, DateTime.utc(2026, 10, 8, 11, 10, 30));
      });
    },
  );

  test('a change of the clock is noticed within a minute', () async {
    await time.run(() async {
      int calls = 0;
      final Scheduler s = scheduler()
        ..cron('0 12 * * *', utc: true, name: 'noon', task: () => calls++);
      s.start();

      // The clock is set two hours ahead (NTP, a manual change): no timer is waiting hours
      time.jump(const Duration(hours: 2));
      await time.advance(const Duration(minutes: 1));

      expect(calls, 1);
    });
  });

  test(
    'each run has a scope: an id, and its scoped dependencies disposed',
    () async {
      await time.run(() async {
        final DependencyInjection injection = DependencyInjection();
        Winter.context.setUp(dependencyInjection: injection);
        addTearDown(
          () =>
              Winter.context.setUp(dependencyInjection: DependencyInjection()),
        );
        final List<String> disposed = [];
        int next = 0;
        injection.putScoped<_Connection>(
          () => _Connection(next++),
          onDispose: (connection) =>
              disposed.add('connection ${connection.id}'),
        );
        final List<String?> ids = [];
        final ScheduledTask task = scheduler().every(
          const Duration(minutes: 1),
          name: 'scoped',
          task: () {
            ids.add(requestId);
            // The same instance during one run
            expect(
              identical(di.find<_Connection>(), di.find<_Connection>()),
              isTrue,
            );
          },
        );

        await task.run();
        await task.run();

        expect(ids, hasLength(2));
        expect(ids.toSet(), hasLength(2), reason: 'an id per run');
        expect(ids, everyElement(isNotNull));
        expect(disposed, ['connection 0', 'connection 1']);
        expect(requestId, isNull, reason: 'no scope outside a run');
      });
    },
  );

  test('runOnStart, run(), and adding a task once started', () async {
    await time.run(() async {
      final List<String> runs = [];
      final Scheduler s = scheduler()
        ..every(
          const Duration(hours: 1),
          name: 'warm-up',
          runOnStart: true,
          task: () => runs.add('warm-up'),
        );
      s.start();
      await FakeTime.flush();
      expect(runs, ['warm-up']);

      final ScheduledTask late = s.every(
        const Duration(minutes: 1),
        name: 'late',
        task: () => runs.add('late'),
      );
      expect(late.nextRun, DateTime.utc(2026, 10, 8, 10, 1, 30));
      await time.advance(const Duration(minutes: 1));
      expect(runs, ['warm-up', 'late']);

      await s['warm-up']!.run();
      expect(runs.last, 'warm-up');
    });
  });

  test('cancel removes a task; a name is unique', () async {
    await time.run(() async {
      int calls = 0;
      final Scheduler s = scheduler();
      final ScheduledTask task = s.every(
        const Duration(minutes: 1),
        name: 'once',
        task: () => calls++,
      );
      s.start();

      expect(
        () => s.every(const Duration(minutes: 1), name: 'once', task: () {}),
        throwsArgumentError,
      );

      task.cancel();
      task.cancel();
      await time.advance(const Duration(minutes: 5));

      expect(calls, 0);
      expect(s.tasks, isEmpty);
      expect(s['once'], isNull);
      expect(task.nextRun, isNull);
      expect(task.toString(), 'ScheduledTask(once, every 0:01:00.000000)');
    });
  });

  test('stop: no more runs, it waits for the ones in progress, and it can start again', () async {
    await time.run(() async {
      final Completer<void> slow = Completer<void>();
      int calls = 0;
      final Scheduler s = scheduler();
      final ScheduledTask task = s.every(
        const Duration(minutes: 1),
        name: 'job',
        task: () {
          calls++;
          return calls == 1 ? slow.future : null;
        },
      );
      s.start();
      s.start(); // nothing
      await time.advance(const Duration(minutes: 1));

      bool stopped = false;
      final Future<void> stopping = s.stop().then((_) => stopped = true);
      await FakeTime.flush();
      expect(stopped, isFalse, reason: 'a run is in progress');
      expect(task.nextRun, isNull);

      slow.complete();
      await stopping;
      await time.advance(const Duration(minutes: 5));
      expect(calls, 1);

      s.start();
      await time.advance(const Duration(minutes: 1));
      expect(calls, 2);
    });
  });

  test('stop with a timeout leaves the runs still in progress', () async {
    final Scheduler s = Scheduler();
    final Completer<void> never = Completer<void>();
    final ScheduledTask task = s.every(
      const Duration(hours: 1),
      name: 'stuck',
      task: () => never.future,
    );
    unawaited(task.run());

    await s.stop(timeout: Duration.zero);

    expect(task.isRunning, isTrue);
    expect(
      logs,
      contains(
        'Leaving 1 scheduled task run(s) still in progress after 0:00:00.000000',
      ),
    );
    never.complete();
  });

  test('a schedule that is never due is logged', () async {
    await time.run(() async {
      final Scheduler s = scheduler()
        ..cron('0 0 30 2 *', utc: true, name: 'never', task: () {});
      s.start();

      expect(s['never']!.nextRun, isNull);
      expect(
        logs,
        contains(
          'The scheduled task "never" (cron "0 0 30 2 *" (UTC)) is never due',
        ),
      );
      expect(time.pendingTimers, 0);
    });
  });

  test('the debug logs of a run, only when debug is on', () async {
    final List<String> debug = [];
    Winter.context.setUp(
      logger: _MemoryLogger(debug, minLevel: LogLevel.debug),
    );
    await Scheduler()
        .every(const Duration(hours: 1), name: 'verbose', task: () {})
        .run();

    expect(debug.first, 'Scheduled task "verbose" started');
    expect(debug.last, startsWith('Scheduled task "verbose" ended ('));
  });
}

class _Connection {
  final int id;

  _Connection(this.id);
}

class _MemoryLogger extends WinterLogger {
  final List<String> logs;
  final LogLevel minLevel;

  _MemoryLogger(this.logs, {this.minLevel = LogLevel.info});

  @override
  bool isEnabled(LogLevel level) => level.index >= minLevel.index;

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    if (isEnabled(level)) logs.add(message);
  }
}
