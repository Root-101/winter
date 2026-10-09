# Scheduled tasks

Code that runs on its own, without a request: purge expired sessions every 5 minutes, send a report
every night at 03:00, refresh a cache every hour. A `Scheduler` runs each task on a `Schedule`
(an interval or a cron expression) and goes up and down with the server.

- `scheduler.every(interval, ...)` and `scheduler.cron('0 3 * * *', ...)` add a task.
- Given to `Winter.start`, it starts once the port is open, and the graceful shutdown waits for
  the tasks in progress like for the requests.
- A task that fails is logged and runs again the next time: it never stops the server nor the
  other tasks.

Examples, one file per case: [`example/scheduling`](../example/scheduling).

## Minimal example

```dart
import 'package:winter/winter.dart';

void main() async {
  final scheduler = Scheduler()
    ..every(
      const Duration(minutes: 5),
      name: 'purge-sessions',
      task: () => di.find<SessionStore>().purgeExpired(),
    )
    ..cron(
      '0 3 * * *', // every day at 03:00
      name: 'nightly-report',
      task: () async => await di.find<Reports>().sendNightly(),
    );

  await Winter.start(router: router, scheduler: scheduler);
}
```

```text
INFO  Scheduler started with 2 task(s)
INFO  Server started on port 8080 (0.012 sec)
```

## How it works

### Schedules

| Code                                       | When it runs                                              |
|--------------------------------------------|-----------------------------------------------------------|
| `Schedule.every(Duration(minutes: 5))`     | every 5 minutes, from the start of the scheduler          |
| `Schedule.cron('0 3 * * *')`               | every day at 03:00, local time                            |
| `Schedule.cron('0 3 * * *', utc: true)`    | every day at 03:00 UTC                                    |
| `Schedule.cron('*/15 9-18 * * MON-FRI')`   | every 15 minutes from 9:00 to 18:45, Monday to Friday     |
| `Schedule.cron('0 0 1 * *')`               | the first day of every month at midnight                  |
| `Schedule.cron('@hourly')`                 | at the start of every hour                                |

`scheduler.every(...)` and `scheduler.cron(...)` are shortcuts of
`scheduler.schedule(Schedule..., name:, task:)`.

**`every`** counts from the time the previous run was due, not from when it ended: a task of 5
minutes that takes 20 seconds still runs at :00, :05, :10. The first run is one interval after the
start (`runOnStart: true` also runs it at the start).

**A cron expression** has 5 fields:

```text
┌───────────── minute        0-59
│ ┌─────────── hour          0-23
│ │ ┌───────── day of month  1-31
│ │ │ ┌─────── month         1-12 or JAN-DEC
│ │ │ │ ┌───── day of week   0-7 or SUN-SAT (0 and 7 are Sunday)
│ │ │ │ │
* * * * *
```

Each field is `*`, a value (`5`), a range (`1-5`), a step (`*/15`, `0-30/10`, `5/10` from 5 to the
end) or a list of them (`1,15,30`). Names are case insensitive. The macros `@yearly`
(`@annually`), `@monthly`, `@weekly`, `@daily` (`@midnight`) and `@hourly` work too.

- When both the day of the month and the day of the week are restricted, a day matches if
  **either** matches, as in cron: `0 0 1 * MON` is the 1st of every month and every Monday. A
  field that starts with `*` (`*/2`) counts as unrestricted.
- The times are **local** by default (as in cron). With `utc: true` they are UTC, the same in any
  machine; containers usually run in UTC anyway.
- An invalid expression is a `FormatException` when the task is added, which says which field is
  wrong: `the hour 24 is out of 0-23`.
- A day that never exists (`0 0 30 2 *`) is never due: the task never runs, and a warning says so.

A schedule of your own implements `next`, the first time it's due after a given one:

```dart
class OnWorkingDays extends Schedule {
  @override
  DateTime? next(DateTime after) { ... } // null: never again
}
```

### Each run

- **A scope of its own**: each run happens inside a `RequestScope`, as a request does. Its logs
  have an id (`requestId`), and a `di.putScoped` dependency (a connection, a unit of work) is one
  per run and is disposed when the run ends.
- **Errors**: anything the task throws is logged (`ERROR The scheduled task "nightly-report"
  failed`, with its stack trace), and the task runs again the next time it's due.
- **No overlapping**: a run that is due while the previous one is still running is skipped, with a
  warning. With `allowOverlap: true` it starts anyway.
- **The time is checked at least once a minute**, so a change of the clock (NTP, a manual change)
  delays a task one minute at most. Runs missed while the machine was suspended are not repeated:
  the task runs once when it wakes up (`missed 5 run(s)` in the logs), and goes on from the next
  time it's due.
- Each run is logged at `debug` (`Scheduled task "purge-sessions" ended (12 ms)`).

### With the server

`Winter.start(scheduler: ...)` uses the one given, or the one registered in `di`
(`di.put(Scheduler()..every(...))`), or none. It's registered in `di` while the server runs.

| Moment                               | The scheduler                                                  |
|--------------------------------------|----------------------------------------------------------------|
| `Winter.start`                       | starts after the port is open (never for a server that fails)  |
| `Winter.shutdown()` (SIGINT/SIGTERM) | stops; the runs in progress are waited for, up to `shutdownTimeout`, before `onShutdown` and `disposeAll` |
| `Winter.close()`                     | stops, and waits for the runs in progress                      |
| `Winter.close(force: true)`          | stops; the runs in progress are not waited for                 |

Without a server (a worker, a script), call `scheduler.start()` and `await scheduler.stop()`
yourself. `stop(timeout:)` waits for the runs in progress up to `timeout`. A stopped scheduler can
be started again.

### A task: `ScheduledTask`

`every`, `cron` and `schedule` return the task (and `scheduler['name']` finds it):

| Member          | What it is                                                         |
|-----------------|--------------------------------------------------------------------|
| `nextRun`       | when it runs next (null while stopped)                             |
| `lastRun`       | when its last run started                                          |
| `lastSucceeded` | when its last run without an error ended                           |
| `isRunning`     | whether it's running now                                           |
| `run()`         | runs it now, like a scheduled run (in a scope, errors logged)      |
| `cancel()`      | removes it from the scheduler                                      |

A task can be added after the scheduler started: it's scheduled at once. Names are unique (an
`ArgumentError` otherwise): they identify the task in the logs.

## Common cases

### A health check that fails when a job stopped working

```dart
final ScheduledTask report = scheduler.cron('0 3 * * *', name: 'nightly-report', task: sendReport);

Route.health(
  path: '/readyz',
  checks: {
    // The report of last night was sent
    'nightly-report': () {
      final DateTime? sent = report.lastSucceeded;
      return sent != null && DateTime.now().difference(sent) < const Duration(hours: 25);
    },
  },
)
```

### A task that needs a dependency

Find it inside the task, not when the scheduler is built: the dependencies registered later (or
replaced in a test) are the ones used.

```dart
scheduler.every(
  const Duration(minutes: 5),
  name: 'purge-sessions',
  task: () => di.find<SessionStore>().purgeExpired(),
);
```

### Several instances of the server

Every instance runs its own scheduler: with three replicas, the nightly report is sent three
times. Run the tasks that must happen once in one instance only (an environment variable,
`SCHEDULER_ENABLED=true` in one of them), or take a lock in the database at the start of the task.

```dart
final Scheduler? scheduler = (env.find<bool>('SCHEDULER_ENABLED') ?? false)
    ? (Scheduler()..cron('0 3 * * *', name: 'nightly-report', task: sendReport))
    : null;
await Winter.start(router: router, scheduler: scheduler);
```

### Testing a task

Test what the task does by running it, and when it runs with its schedule; no timer needed:

```dart
test('the report runs at 03:00', () {
  final Schedule schedule = Schedule.cron('0 3 * * *', utc: true);

  expect(schedule.next(DateTime.utc(2026, 10, 8, 10)), DateTime.utc(2026, 10, 9, 3));
});

test('the purge removes the expired sessions', () async {
  final scheduler = buildScheduler();
  await scheduler['purge-sessions']!.run();
  expect(store.sessions, isEmpty);
});
```

`Scheduler(clock: ...)` takes the current time from a function, for a test that drives the clock.

## Typical mistakes and limitations

- **Expecting a run at the start** with `every`: the first one is one interval later; use
  `runOnStart: true`.
- **A task that never ends** holds the graceful shutdown up to `shutdownTimeout`: give long tasks
  a timeout of their own.
- **Local times and daylight saving**: a local `30 2 * * *` doesn't exist the day the clock jumps
  from 02:00 to 03:00 (it runs at 03:30), and may run once or twice the day it goes back. Use
  `utc: true` for tasks that must run exactly once a day.
- **Not a job queue**: runs are not persisted. A run missed while the server was down is not
  repeated when it starts again; a task that must catch up checks what it missed itself.
- The precision is the minute: cron has no seconds, and `every` accepts any interval, but a timer
  is never more precise than the event loop.
