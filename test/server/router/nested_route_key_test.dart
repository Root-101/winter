import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  ResponseEntity ok(RequestEntity request) => ResponseEntity.ok();

  RequestEntity request(String method, String path) =>
      RequestEntity(method, Uri.parse('http://localhost$path'));

  test(
    'Children with the same relative path in different parents are kept',
    () {
      final duplicated = <Route>[];
      final router = WinterRouter(
        config: RouterConfig(onDuplicatedRoute: duplicated.add),
        routes: [
          Route.parent(
            path: '/users',
            routes: [Route.get(path: '/{id}', handler: ok)],
          ),
          Route.parent(
            path: '/items',
            routes: [Route.get(path: '/{id}', handler: ok)],
          ),
        ],
      );

      expect(duplicated, isEmpty);
      expect(router.routes.map((route) => route.path), [
        '/users/{id}',
        '/items/{id}',
      ]);
      expect(
        router.handlerRoute(request('GET', '/items/1'))?.path,
        '/items/{id}',
      );
      expect(router.routes[0].key, isNot(router.routes[1].key));
    },
  );

  test(
    'Same relative path in routers with different basePath get different keys',
    () {
      final users = WinterRouter(
        basePath: '/users',
        routes: [Route.get(path: '/{id}', handler: ok)],
      );
      final items = WinterRouter(
        basePath: '/items',
        routes: [Route.get(path: '/{id}', handler: ok)],
      );

      expect(users.routes.single.key, isNot(items.routes.single.key));
    },
  );

  test('Custom keys are kept when the route is nested', () {
    final router = WinterRouter(
      routes: [
        Route.parent(
          path: '/users',
          routes: [Route.get(path: '/{id}', key: 'user-detail', handler: ok)],
        ),
      ],
    );

    expect(router.routes.single.key, 'user-detail');
  });

  test('Real duplicates (same full path & method) are still detected', () {
    final duplicated = <Route>[];
    WinterRouter(
      config: RouterConfig(onDuplicatedRoute: duplicated.add),
      routes: [
        Route.get(path: '/users/{id}', handler: ok),
        Route.parent(
          path: '/users',
          routes: [Route.get(path: '/{id}', handler: ok)],
        ),
      ],
    );

    expect(duplicated.map((route) => route.path), ['/users/{id}']);
  });

  group('addRoute', () {
    test('applies the basePath and adds the children of a parent route', () {
      final router = WinterRouter(basePath: '/api', routes: []);

      router.addRoute(
        Route.parent(
          path: '/users',
          routes: [
            Route.get(path: '/{id}', handler: ok),
            Route.delete(path: '/{id}', handler: ok),
          ],
        ),
      );

      expect(router.routes.map((route) => '${route.method} ${route.path}'), [
        'get /api/users/{id}',
        'delete /api/users/{id}',
      ]);
      expect(router.handlerRoute(request('GET', '/api/users/1')), isNotNull);
    });

    test('detects duplicates with the existing routes', () {
      final duplicated = <Route>[];
      final router = WinterRouter(
        config: RouterConfig(onDuplicatedRoute: duplicated.add),
        routes: [Route.get(path: '/users', handler: ok)],
      );

      router.addRoute(Route.get(path: '/users/', handler: ok));

      expect(router.routes, hasLength(1));
      expect(duplicated, hasLength(1));
    });

    test('invalid urls are not added', () {
      final invalid = <Route>[];
      final router = WinterRouter(
        config: RouterConfig(onInvalidUrl: invalid.add),
        routes: [],
      );

      router.addRoute(Route.get(path: '/in valid', handler: ok));

      expect(router.routes, isEmpty);
      expect(invalid, hasLength(1));
    });
  });
}
