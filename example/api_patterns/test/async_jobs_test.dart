import 'dart:async';

import 'package:api_patterns_examples/async_jobs.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  // The job finishes when the test completes it: no waiting on the clock
  late Completer<String> work;
  late WinterTestClient client;

  setUp(() {
    work = Completer<String>();
    client = WinterTestClient.build(
      router: router(JobRunner(() => work.future)),
    );
  });

  test('202 with the Location of the job, then 303 to the result', () async {
    final accepted = await client.post('/reports');
    expect(accepted.statusCode, 202);
    expect(accepted.headers['location'], '/jobs/1');
    expect(accepted.headers['retry-after'], '2');

    final running = await client.get('/jobs/1');
    expect(running.statusCode, 200);
    expect((running.json as Map)['state'], 'running');
    expect((await client.get('/reports/1')).statusCode, 404);

    work.complete('Sales: 1200');
    await pumpEventQueue();

    final done = await client.get('/jobs/1');
    expect(done.statusCode, 303);
    expect(done.headers['location'], '/reports/1');
    expect((await client.get('/reports/1')).json, {'report': 'Sales: 1200'});
  });

  test('a failed job is a 500 with a detail, and is logged', () async {
    await client.post('/reports');

    work.completeError(StateError('the database is down'));
    await pumpEventQueue();

    final response = await client.get('/jobs/1');
    expect(response.statusCode, 500);
    expect(
      (response.json as Map)['detail'],
      'The report could not be generated',
    );
  });

  test('an unknown job is a 404', () async {
    expect((await client.get('/jobs/9')).statusCode, 404);
  });
}
