import 'dart:async';

import 'package:api_patterns_examples/request_timeout.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Runs [body] where every timer fires at once: the limit is tested without waiting for it
Future<T> instantTimers<T>(Future<T> Function() body) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(
    createTimer: (self, parent, zone, duration, callback) =>
        parent.createTimer(zone, Duration.zero, callback),
  ),
);

void main() {
  // A report that never ends: only the limit can answer
  late Completer<String> stuck;
  setUp(() => stuck = Completer<String>());

  WinterTestClient client({Duration? requestTimeout}) => WinterTestClient.build(
    router: router(buildReport: () => stuck.future),
    requestTimeout: requestTimeout,
  );

  test('a fast route answers as always', () async {
    final response = await instantTimers(
      () => client(requestTimeout: timeout).get('/ping'),
    );

    expect(response.statusCode, 200);
    expect(response.body, 'pong');
  });

  test('a route that takes longer than the limit is a 503', () async {
    final response = await instantTimers(
      () => client(requestTimeout: timeout).get('/report'),
    );

    expect(response.statusCode, 503);
    expect(
      response.headers['content-type'],
      startsWith('application/problem+json'),
    );
    expect((response.json as Map)['status'], 503);
  });

  test('without requestTimeout (the default) nothing limits it', () async {
    final Future<TestResponse> response = client().get('/report');
    var answered = false;
    unawaited(response.then((_) => answered = true));

    await instantTimers(() => Future<void>.delayed(Duration.zero));
    expect(answered, isFalse);

    stuck.complete('report');
    expect((await response).body, 'report');
  });
}
