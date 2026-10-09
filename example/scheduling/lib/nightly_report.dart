/// A cron task every night at 03:00 UTC, and a health check that fails when the last report is
/// older than a day (`lastSucceeded`): the job stopped working, the load balancer should know.
///
/// Run: `dart run lib/nightly_report.dart`, then `curl -i localhost:8080/readyz`
library;

import 'package:winter/winter.dart';

/// A stand-in for an email service
class Reports {
  final List<String> sent = [];

  /// Fails when [failing] (the mail server is down)
  bool failing = false;

  Future<void> sendNightly() async {
    if (failing) throw StateError('The mail server is down');
    sent.add('report ${sent.length + 1}');
  }
}

/// The scheduler of the app, and its health check on the same task
(Scheduler, WinterRouter) app({DateTime Function()? clock}) {
  final DateTime Function() now = clock ?? DateTime.now;
  final Scheduler scheduler = Scheduler(clock: clock);
  final ScheduledTask report = scheduler.cron(
    '0 3 * * *',
    utc: true,
    name: 'nightly-report',
    task: () => di.find<Reports>().sendNightly(),
  );
  final WinterRouter router = WinterRouter(
    routes: [
      Route.health(
        path: '/readyz',
        checks: {
          'nightly-report': () {
            final DateTime? sent = report.lastSucceeded;
            return sent != null &&
                now().difference(sent) < const Duration(hours: 25);
          },
        },
      ),
    ],
  );
  return (scheduler, router);
}

Future<void> main() async {
  di.put(Reports());
  final (Scheduler scheduler, WinterRouter router) = app();
  // Once at the start, so the health check is green from the beginning
  await scheduler['nightly-report']!.run();
  await Winter.start(router: router, scheduler: scheduler);
}
