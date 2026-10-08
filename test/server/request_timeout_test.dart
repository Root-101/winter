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
  }) => logs.add('${level.name}: $message');
}

/// Runs [body] where every timer fires at once (after the pending microtasks), and records its
/// duration: the timeout is tested without waiting on the real clock
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
  const Duration timeout = Duration(seconds: 30);

  late _MemoryLogger memoryLogger;
  late Completer<ResponseEntity> stuck;

  setUp(() {
    memoryLogger = _MemoryLogger();
    Winter.context.setUp(logger: memoryLogger);
    stuck = Completer<ResponseEntity>();
  });

  tearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));

  WinterTestClient client({
    Duration? requestTimeout = timeout,
    SecurityConfig? securityConfig,
    FilterConfig? globalFilterConfig,
  }) => WinterTestClient.build(
    requestTimeout: requestTimeout,
    securityConfig: securityConfig,
    globalFilterConfig: globalFilterConfig,
    router: WinterRouter(
      routes: [
        Route.get(
          path: '/fast',
          handler: (r) => ResponseEntity.ok(body: 'ok'),
        ),
        Route.get(path: '/stuck', handler: (r) => stuck.future),
      ],
    ),
  );

  group('ServerConfig.requestTimeout', () {
    test('a handler that takes longer is a 503 Problem Details', () async {
      final List<Duration> timers = [];
      final TestResponse response = await _instantTimers(
        timers,
        () => client().get('/stuck?token=secret'),
      );

      expect(response.statusCode, 503);
      expect(
        response.headers['content-type'],
        startsWith('application/problem+json'),
      );
      expect(
        jsonDecode(response.body),
        containsPair('detail', 'The request took too long'),
      );
      expect(response.headers['x-request-id'], isNotEmpty);
      expect(timers, contains(timeout));
      expect(memoryLogger.logs, [
        'warning: The request GET /stuck took more than $timeout, answered with a 503',
      ]);
    });

    test('a response in time is not touched', () async {
      final List<Duration> timers = [];
      final TestResponse response = await _instantTimers(
        timers,
        () => client().get('/fast'),
      );

      expect(response.statusCode, 200);
      expect(response.body, 'ok');
      expect(timers, [timeout]);
      expect(memoryLogger.logs, isEmpty);
    });

    test('the 503 goes through CORS and the outer filters', () async {
      final TestResponse response = await _instantTimers(
        [],
        () => client(
          securityConfig: SecurityConfig(
            cors: const CorsConfig(allowedOrigins: ['https://app.com']),
          ),
        ).get('/stuck', headers: {'Origin': 'https://app.com'}),
      );

      expect(response.statusCode, 503);
      expect(
        response.headers['access-control-allow-origin'],
        'https://app.com',
      );
    });

    test('a filter of the app that gets stuck is timed too', () async {
      final TestResponse response = await _instantTimers(
        [],
        () => client(
          globalFilterConfig: FilterConfig([_StuckFilter(stuck.future)]),
        ).get('/fast'),
      );

      expect(response.statusCode, 503);
    });

    test('a late error of the handler is logged, never uncaught', () async {
      final TestResponse response = await _instantTimers(
        [],
        () => client().get('/stuck'),
      );
      stuck.completeError(StateError('too late'));
      await Future<void>.delayed(Duration.zero);

      expect(response.statusCode, 503);
      expect(memoryLogger.logs, [
        startsWith('warning: The request GET /stuck took more than'),
        'error: Unhandled error in GET /stuck',
      ]);
    });

    test('without it there is no timer', () async {
      final List<Duration> timers = [];
      await _instantTimers(
        timers,
        () => client(requestTimeout: null).get('/fast'),
      );

      expect(timers, isEmpty);
    });

    test('must be positive', () {
      for (final Duration invalid in [
        Duration.zero,
        const Duration(seconds: -1),
      ]) {
        expect(
          () => ServerConfig(requestTimeout: invalid).validate(),
          throwsArgumentError,
          reason: '$invalid',
        );
      }
      const ServerConfig(requestTimeout: Duration(milliseconds: 1)).validate();
      expect(
        ServerConfig.fromEnv(
          Env(env: const {}),
          requestTimeout: timeout,
        ).requestTimeout,
        timeout,
      );
    });
  });
}

class _StuckFilter extends Filter {
  final Future<ResponseEntity> stuck;

  _StuckFilter(this.stuck);

  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) =>
      stuck;
}
