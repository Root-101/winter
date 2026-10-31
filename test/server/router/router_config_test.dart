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

void main() {
  ResponseEntity ok(RequestEntity request) => ResponseEntity.ok();

  late _MemoryLogger logger;

  setUp(() {
    logger = _MemoryLogger();
    Winter.context.setUp(logger: logger);
  });

  tearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));

  group('RouterConfig', () {
    test('invalid urls are excluded and logged as warnings with ignore()', () {
      final router = WinterRouter(
        config: RouterConfig(onInvalidUrl: DefaultOnInvalidUrl.ignore()),
        routes: [Route.get(path: '/in valid', handler: ok)],
      );

      expect(router.routes, isEmpty);
      expect(
        logger.logs.single,
        startsWith('warning: /in valid is not a valid URL'),
      );
    });

    test('invalid urls are not logged with ignore(log: false)', () {
      WinterRouter(
        config: RouterConfig(
          onInvalidUrl: DefaultOnInvalidUrl.ignore(log: false),
        ),
        routes: [Route.get(path: '/in valid', handler: ok)],
      );

      expect(logger.logs, isEmpty);
    });

    test(
      'DefaultOnInvalidUrl.fail makes the WinterRouter constructor throw',
      () {
        expect(
          () => WinterRouter(
            config: RouterConfig(onInvalidUrl: DefaultOnInvalidUrl.fail()),
            routes: [Route.get(path: '/in valid', handler: ok)],
          ),
          throwsStateError,
        );
      },
    );

    test('the same custom key on different paths is a duplicate', () {
      expect(
        () => WinterRouter(
          routes: [
            Route.get(path: '/test1', key: 'duplicate-key', handler: ok),
            Route.get(path: '/test2', key: 'duplicate-key', handler: ok),
          ],
        ),
        throwsStateError,
      );
    });

    test('DefaultOnDuplicatedRoute.ignore keeps the first route', () async {
      final client = WinterTestClient.build(
        router: WinterRouter(
          config: RouterConfig(
            onDuplicatedRoute: DefaultOnDuplicatedRoute.ignore(log: false),
          ),
          routes: [
            Route.get(
              path: '/test',
              handler: (r) => ResponseEntity.ok(body: 'first'),
            ),
            Route.get(
              path: '/test',
              handler: (r) => ResponseEntity.ok(body: 'second'),
            ),
          ],
        ),
      );

      final response = await client.get('/test');

      expect(response.statusCode, 200);
      expect(response.body, 'first');
      expect(logger.logs, isEmpty);
    });

    test('DefaultOnLoadedRoutes.log logs one line per route', () {
      WinterRouter(
        config: RouterConfig(onLoadedRoutes: DefaultOnLoadedRoutes.log()),
        basePath: '/api',
        routes: [
          Route.get(path: '/users', handler: ok),
          Route.delete(path: '/users/{id}', handler: ok),
          Route(path: '/users', method: HttpMethod.options, handler: ok),
        ],
      );

      expect(logger.logs, [
        'info: Routes log start ======================================',
        'info: GET      /api/users       key: GET /api/users          filters: []',
        'info: DELETE   /api/users/{id}  key: DELETE /api/users/{id}  filters: []',
        'info: OPTIONS  /api/users       key: OPTIONS /api/users      filters: []',
        'info: Routes log end ========================================',
      ]);
      // One entry per route: a line break or a terminal code would be escaped by the logger
      for (final log in logger.logs) {
        expect(log, isNot(contains('\n')));
        expect(log, isNot(contains('\x1B')));
      }
    });

    test('DefaultOnLoadedRoutes.ignore (default) logs nothing', () {
      WinterRouter(
        routes: [Route.get(path: '/users', handler: ok)],
      );

      expect(logger.logs, isEmpty);
    });
  });

  group('Route', () {
    test('factories set the method', () {
      expect(Route.get(path: '/a', handler: ok).method, HttpMethod.get);
      expect(Route.post(path: '/a', handler: ok).method, HttpMethod.post);
      expect(Route.put(path: '/a', handler: ok).method, HttpMethod.put);
      expect(Route.patch(path: '/a', handler: ok).method, HttpMethod.patch);
      expect(Route.delete(path: '/a', handler: ok).method, HttpMethod.delete);
      expect(Route.query(path: '/a', handler: ok).method, HttpMethod.query);
      expect(Route.parent(path: '/a').method, isNull);
    });

    test('a path must start with a slash', () {
      expect(() => Route.get(path: 'users', handler: ok), throwsArgumentError);
    });

    test('method & handler go together', () {
      expect(() => Route(path: '/a', handler: ok), throwsArgumentError);
      expect(
        () => Route(path: '/a', method: HttpMethod.get),
        throwsArgumentError,
      );
    });

    test('toString of a route & a router include the paths', () {
      final router = WinterRouter(
        basePath: '/api',
        routes: [Route.get(path: '/users', handler: ok)],
      );

      expect(router.routes.single.toString(), contains('/api/users'));
      expect(router.toString(), contains('basePath: /api'));
    });
  });
}
