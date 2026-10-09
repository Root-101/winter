import 'dart:async';
import 'dart:collection';

import 'package:winter/winter.dart';

/// The code of a scheduled task
///
/// {@category Scheduling}
typedef ScheduledTaskFunction = FutureOr<void> Function();

/// Runs tasks on a [Schedule]: every so often, or on a cron expression.
///
/// ```dart
/// final scheduler = Scheduler()
///   ..every(const Duration(minutes: 5), name: 'purge-sessions', task: sessions.purgeExpired)
///   ..cron('0 3 * * *', name: 'nightly-report', task: reports.sendNightly);
///
/// await Winter.start(router: router, scheduler: scheduler);
/// ```
///
/// - Given to `Winter.start` (or registered in `di`), it starts once the port is open, and a
///   graceful shutdown stops it and waits for the tasks in progress, like the requests.
///   Without a server, call [start] and [stop] yourself.
/// - Each run has a [RequestScope] of its own: its logs have an id, and the scoped dependencies
///   (`di.putScoped`) live for that run and are disposed when it ends.
/// - A task that fails is logged, and runs again the next time it's due: one task never stops
///   the others.
/// - A run that is due while the previous one is still running is skipped (and logged), unless the
///   task allows overlapping runs.
/// - The time is checked at least once a minute, so a change of the clock or a suspended machine
///   delays a task one minute at most. Runs missed while suspended are not repeated: the task runs
///   once, and goes on from the next time it's due.
///
/// {@category Scheduling}
class Scheduler {
  final DateTime Function() _clock;
  final List<ScheduledTask> _tasks = [];
  final Set<Future<void>> _running = {};
  bool _started = false;

  /// A scheduler with no tasks. [clock] gives the current time (tests can fake it).
  Scheduler({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// The tasks, in the order they were added
  List<ScheduledTask> get tasks => UnmodifiableListView(_tasks);

  /// Whether it's started: its tasks run when they're due
  bool get isStarted => _started;

  /// The task called [name], or null
  ScheduledTask? operator [](String name) =>
      _tasks.where((task) => task.name == name).firstOrNull;

  /// Runs [task] on [schedule]. [name] identifies it in the logs and must be unique.
  ///
  /// With [runOnStart], it also runs once when the scheduler starts. With [allowOverlap], a run
  /// that is due while the previous one is running starts anyway.
  ScheduledTask schedule(
    Schedule schedule, {
    required String name,
    required ScheduledTaskFunction task,
    bool runOnStart = false,
    bool allowOverlap = false,
  }) {
    if (this[name] != null) {
      throw ArgumentError.value(
        name,
        'name',
        'there is already a task with this name',
      );
    }
    final ScheduledTask scheduled = ScheduledTask._(
      this,
      name,
      schedule,
      task,
      runOnStart: runOnStart,
      allowOverlap: allowOverlap,
    );
    _tasks.add(scheduled);
    if (_started) scheduled._start(_clock());
    return scheduled;
  }

  /// Runs [task] every [interval] (see [Schedule.every] and [schedule])
  ScheduledTask every(
    Duration interval, {
    required String name,
    required ScheduledTaskFunction task,
    bool runOnStart = false,
    bool allowOverlap = false,
  }) => schedule(
    Schedule.every(interval),
    name: name,
    task: task,
    runOnStart: runOnStart,
    allowOverlap: allowOverlap,
  );

  /// Runs [task] on a cron [expression] (see [Schedule.cron] and [schedule])
  ScheduledTask cron(
    String expression, {
    required String name,
    required ScheduledTaskFunction task,
    bool utc = false,
    bool allowOverlap = false,
  }) => schedule(
    Schedule.cron(expression, utc: utc),
    name: name,
    task: task,
    allowOverlap: allowOverlap,
  );

  /// Starts running the tasks when they're due. Starting it again does nothing.
  void start() {
    if (_started) return;
    _started = true;
    final DateTime now = _clock();
    for (final ScheduledTask task in _tasks) {
      task._start(now);
    }
    logger.info(
      'Scheduler started with ${_tasks.length} task(s)',
      fields: {'tasks': _tasks.map((task) => task.name).toList()},
    );
  }

  /// Stops running the tasks, and waits for the runs in progress: up to [timeout] if given (the
  /// ones still running then are left running, and logged). It can be started again.
  Future<void> stop({Duration? timeout}) async {
    if (_started) {
      _started = false;
      for (final ScheduledTask task in _tasks) {
        task._stop();
      }
    }
    if (_running.isEmpty) return;
    final Future<void> done = Future.wait(_running.toList()).then<void>((_) {});
    if (timeout == null) return done;
    await done.timeout(
      timeout,
      onTimeout: () => logger.warning(
        'Leaving ${_running.length} scheduled task run(s) still in progress after $timeout',
      ),
    );
  }

  void _remove(ScheduledTask task) => _tasks.remove(task);
}

/// A task of a [Scheduler]: when it runs next, when it ran, and a way to run it now or cancel it.
///
/// {@category Scheduling}
class ScheduledTask {
  final Scheduler _scheduler;

  /// Its name, in the logs
  final String name;

  /// When it runs
  final Schedule schedule;

  final ScheduledTaskFunction _task;

  /// Whether it runs once when the scheduler starts
  final bool runOnStart;

  /// Whether a run starts even if the previous one is still running
  final bool allowOverlap;

  Timer? _timer;
  DateTime? _nextRun;
  DateTime? _lastRun;
  DateTime? _lastSucceeded;
  int _runningCount = 0;
  bool _cancelled = false;

  ScheduledTask._(
    this._scheduler,
    this.name,
    this.schedule,
    this._task, {
    required this.runOnStart,
    required this.allowOverlap,
  });

  /// The longest wait between two checks of the time
  static const Duration _maxWait = Duration(minutes: 1);

  /// When it runs next, or null when the scheduler is stopped (or it's never due again)
  DateTime? get nextRun => _nextRun;

  /// When its last run started, or null if it never ran
  DateTime? get lastRun => _lastRun;

  /// When its last successful run ended, or null if none ended without an error. Useful for a
  /// health check: `task.lastSucceeded` older than a day means the nightly job is failing.
  DateTime? get lastSucceeded => _lastSucceeded;

  /// Whether it's running now
  bool get isRunning => _runningCount > 0;

  void _start(DateTime now) {
    _nextRun = schedule.next(now);
    if (_nextRun == null) {
      logger.warning('The scheduled task "$name" ($schedule) is never due');
    }
    _wait();
    if (runOnStart) unawaited(run());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _nextRun = null;
  }

  /// Waits until [_nextRun], checking the time at least once a minute
  void _wait() {
    final DateTime? due = _nextRun;
    if (due == null) return;
    Duration delay = due.difference(_scheduler._clock());
    if (delay < Duration.zero) delay = Duration.zero;
    if (delay > _maxWait) delay = _maxWait;
    _timer = Timer(delay, _check);
  }

  void _check() {
    final DateTime? due = _nextRun;
    if (due == null) return;
    final DateTime now = _scheduler._clock();
    if (now.isBefore(due)) return _wait();

    unawaited(run());

    // The next time after now: the runs missed (a suspended machine) are not repeated
    DateTime? next = schedule.next(due);
    int missed = 0;
    while (next != null && !next.isAfter(now)) {
      missed++;
      next = schedule.next(next);
    }
    if (missed > 0) {
      logger.warning('The scheduled task "$name" missed $missed run(s)');
    }
    _nextRun = next;
    _wait();
  }

  /// Runs it now, like a scheduled run (in a scope of its own, an error logged and not thrown),
  /// and completes when it ends. Skipped if it's running and doesn't allow overlapping runs.
  Future<void> run() {
    if (isRunning && !allowOverlap) {
      logger.warning(
        'Skipping a run of the scheduled task "$name": the previous one is still running',
      );
      return Future<void>.value();
    }
    final Future<void> execution = _execute();
    _scheduler._running.add(execution);
    return execution.whenComplete(() => _scheduler._running.remove(execution));
  }

  Future<void> _execute() async {
    _runningCount++;
    final DateTime start = _scheduler._clock();
    _lastRun = start;
    final RequestScope scope = RequestScope();
    try {
      await RequestScope.run(scope, () async {
        if (logger.isEnabled(LogLevel.debug)) {
          logger.debug('Scheduled task "$name" started');
        }
        try {
          await _task();
          _lastSucceeded = _scheduler._clock();
          if (logger.isEnabled(LogLevel.debug)) {
            logger.debug(
              'Scheduled task "$name" ended '
              '(${_scheduler._clock().difference(start).inMilliseconds} ms)',
            );
          }
        } catch (error, stackTrace) {
          logger.error(
            'The scheduled task "$name" failed',
            error: error,
            stackTrace: stackTrace,
          );
        } finally {
          await scope.complete();
        }
      });
    } finally {
      _runningCount--;
    }
  }

  /// Removes it from its scheduler: it won't run again (a run in progress goes on)
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _stop();
    _scheduler._remove(this);
  }

  @override
  String toString() => 'ScheduledTask($name, $schedule)';
}
