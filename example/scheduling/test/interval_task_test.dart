import 'package:scheduling_examples/interval_task.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late DateTime now;
  late SessionStore store;

  setUp(() {
    now = DateTime.utc(2026, 10, 8, 10);
    store = SessionStore(clock: () => now)
      ..open('short', const Duration(minutes: 1))
      ..open('long', const Duration(hours: 1));
    di.put(store);
  });

  test('the task purges the expired sessions', () async {
    final ScheduledTask purge = scheduler()['purge-sessions']!;

    await purge.run();
    expect(store.count, 2);

    now = now.add(const Duration(minutes: 2));
    await purge.run();
    expect(store.count, 1);
    expect(purge.lastSucceeded, isNotNull);
  });

  test('every 5 minutes, and once at the start', () {
    final ScheduledTask purge = scheduler()['purge-sessions']!;

    expect(purge.runOnStart, isTrue);
    expect(purge.schedule.next(now), now.add(const Duration(minutes: 5)));
  });

  test('the API sees the same store', () async {
    final client = WinterTestClient.build(router: router());

    expect((await client.get('/sessions')).json, {'open': 2});
  });
}
