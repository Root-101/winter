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
    test('invalid urls are excluded and logged as warnings by default', () {
      final router = WinterRouter(
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

    test('invalid urls fail the start with DefaultOnInvalidUrl.fail', () {
      expect(
        () => WinterRouter(
          config: RouterConfig(onInvalidUrl: DefaultOnInvalidUrl.fail()),
          routes: [Route.get(path: '/in valid', handler: ok)],
        ),
        throwsStateError,
      );
    });

    test(
      'duplicated routes fail the start with DefaultOnDuplicatedRoute.fail',
      () {
        expect(
          () => WinterRouter(
            config: RouterConfig(
              onDuplicatedRoute: DefaultOnDuplicatedRoute.fail(),
            ),
            routes: [
              Route.get(path: '/a', handler: ok),
              Route.get(path: '/a', handler: ok),
            ],
          ),
          throwsStateError,
        );
      },
    );

    test('DefaultOnLoadedRoutes.log logs every route once', () {
      WinterRouter(
        config: RouterConfig(onLoadedRoutes: DefaultOnLoadedRoutes.log()),
        basePath: '/api',
        routes: [
          Route.get(path: '/users', handler: ok),
          Route.delete(path: '/users/{id}', handler: ok),
          Route(path: '/users', method: HttpMethod.options, handler: ok),
        ],
      );

      final log = logger.logs.single;
      expect(log, startsWith('info: Routes log start'));
      expect(log, contains('/api/users'));
      expect(log, contains('/api/users/{id}'));
      expect(log, contains('DELETE'));
      expect(log, contains('OPTIONS'));
      expect(log, contains('Routes log end'));
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
