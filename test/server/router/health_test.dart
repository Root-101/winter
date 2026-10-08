import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

class _MemoryLogger extends WinterLogger {
  final List<String> logs = [];

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => logs.add('${level.name}: $message${error == null ? '' : ' ($error)'}');
}

/// Runs [body] where every timer fires at once and records its duration (no real clock)
Future<T> _instantTimers<T>(List<Duration> timers, Future<T> Function() body) =>
    runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          timers.add(duration);
          return parent.createTimer(zone, Duration.zero, callback);
        },
      ),
    );

void main() {
  late _MemoryLogger memoryLogger;

  setUp(() {
    memoryLogger = _MemoryLogger();
    Winter.context.setUp(logger: memoryLogger);
  });

  tearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));

  WinterTestClient client(List<Route> routes) =>
      WinterTestClient.build(router: WinterRouter(routes: routes));

  Map<String, Object?> json(TestResponse response) =>
      jsonDecode(response.body) as Map<String, Object?>;

  group('Route.health', () {
    test('without checks it is UP while the server answers', () async {
      final TestResponse response = await client([Route.health()])
          .get('/health');

      expect(response.statusCode, 200);
      expect(json(response), {'status': 'UP'});
      expect(
        response.headers['content-type'],
        'application/json; charset=utf-8',
      );
      expect(response.headers['cache-control'], 'no-store');
    });

    test('every check UP is a 200 with each one', () async {
      final TestResponse response = await client([
        Route.health(
          path: '/readyz',
          checks: {'database': () async => true, 'cache': () => true},
        ),
      ]).get('/readyz');

      expect(response.statusCode, 200);
      expect(json(response), {
        'status': 'UP',
        'checks': {'database': 'UP', 'cache': 'UP'},
      });
      expect(memoryLogger.logs, isEmpty);
    });

    test(
      'a check that is false or throws is a 503 DOWN, without the reason',
      () async {
        final TestResponse response = await client([
          Route.health(
            checks: {
              'database': () => throw StateError('password=hunter2 refused'),
              'queue': () async => false,
              'cache': () => true,
            },
          ),
        ]).get('/health');

        expect(response.statusCode, 503);
        expect(
          response.headers['content-type'],
          'application/json; charset=utf-8',
        );
        expect(json(response), {
          'status': 'DOWN',
          'checks': {'database': 'DOWN', 'queue': 'DOWN', 'cache': 'UP'},
        });
        expect(response.body, isNot(contains('hunter2')));
        expect(memoryLogger.logs, [
          'warning: The health check database failed (Bad state: password=hunter2 refused)',
          'warning: The health check queue is down',
        ]);
      },
    );

    test('a check that takes longer than the timeout is DOWN', () async {
      final List<Duration> timers = [];
      final TestResponse response = await _instantTimers(
        timers,
        () => client([
          Route.health(
            timeout: const Duration(seconds: 2),
            checks: {'slow': () => Completer<bool>().future},
          ),
        ]).get('/health'),
      );

      expect(response.statusCode, 503);
      expect(json(response)['checks'], {'slow': 'DOWN'});
      expect(timers, [const Duration(seconds: 2)]);
      expect(memoryLogger.logs, [
        'warning: The health check slow took more than 0:00:02.000000',
      ]);
    });

    test('the checks run at once', () async {
      final List<String> started = [];
      final Completer<bool> first = Completer<bool>();
      final Completer<bool> second = Completer<bool>();
      final Future<TestResponse> response = client([
        Route.health(
          checks: {
            'first': () {
              started.add('first');
              return first.future;
            },
            'second': () {
              started.add('second');
              return second.future;
            },
          },
        ),
      ]).get('/health');

      await Future<void>.delayed(Duration.zero);
      expect(started, ['first', 'second']);
      second.complete(true);
      first.complete(true);
      expect((await response).statusCode, 200);
    });

    test('HEAD has no body, and the checks are copied', () async {
      final Map<String, HealthCheck> checks = {'a': () => true};
      final WinterTestClient health = client([Route.health(checks: checks)]);
      checks['b'] = () => false;

      final TestResponse head = await health.head('/health');

      expect(head.statusCode, 200);
      expect(head.body, isEmpty);
      expect(json(await health.get('/health'))['checks'], {'a': 'UP'});
    });

    test('a timeout that is not positive is an ArgumentError', () {
      expect(() => Route.health(timeout: Duration.zero), throwsArgumentError);
    });
  });
}
