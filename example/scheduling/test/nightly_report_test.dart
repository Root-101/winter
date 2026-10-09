import 'package:scheduling_examples/nightly_report.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late DateTime now;
  late Reports reports;
  late Scheduler scheduler;
  late WinterTestClient client;

  setUp(() {
    now = DateTime.utc(2026, 10, 8, 3);
    reports = Reports();
    di.put(reports);
    final (Scheduler s, WinterRouter router) = app(clock: () => now);
    scheduler = s;
    client = WinterTestClient.build(router: router);
  });

  Future<int> readiness() async => (await client.get('/readyz')).statusCode;

  test('every day at 03:00 UTC', () {
    final Schedule schedule = scheduler['nightly-report']!.schedule;

    expect(
      schedule.next(DateTime.utc(2026, 10, 8, 10)),
      DateTime.utc(2026, 10, 9, 3),
    );
  });

  test('the health check follows the last report sent', () async {
    expect(await readiness(), 503, reason: 'never sent');

    await scheduler['nightly-report']!.run();
    expect(reports.sent, ['report 1']);
    expect(await readiness(), 200);

    // The next night the mail server is down: the report fails, and a day later it's a 503
    reports.failing = true;
    now = now.add(const Duration(days: 1));
    await scheduler['nightly-report']!.run();
    expect(await readiness(), 200, reason: 'yesterday\'s is still recent');

    now = now.add(const Duration(hours: 2));
    expect(await readiness(), 503);
  });
}
