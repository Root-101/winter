# Scheduled tasks examples

One file per case, each a server of its own: `dart run lib/<case>.dart` (port 8080). The tests run
each task without waiting for its time (`task.run()`, `schedule.next(...)`): `dart test`.

| Case | File | What it shows |
|------|------|---------------|
| A task every few minutes | [`interval_task.dart`](lib/interval_task.dart) | `scheduler.every`, `runOnStart`, a dependency found in `di` when it runs, `Winter.start(scheduler:)` |
| A nightly report | [`nightly_report.dart`](lib/nightly_report.dart) | `scheduler.cron('0 3 * * *', utc: true)`, a `Route.health` check on `lastSucceeded`, a fake clock in the tests |

```bash
dart run lib/nightly_report.dart
curl -i localhost:8080/readyz
```

Guide: [scheduled tasks](../../doc/scheduling.md).
