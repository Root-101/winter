@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The behavior decided in the review of the router, the filters and the entities
/// (DECISIONS.md §9)
void main() {
  ResponseEntity ok(RequestEntity request) => ResponseEntity.ok(body: 'ok');

  group('Repeated slashes (§9.1)', () {
    final client = WinterTestClient.build(
      router: WinterRouter(
        routes: [Route.get(path: '/users/{id}', handler: ok)],
      ),
    );

    test('are a 404 that goes through the pipeline', () async {
      for (final path in ['//users/1', '/users//1', '//']) {
        final response = await client.get(path);

        expect(response.statusCode, 404, reason: path);
        expect(response.headers['content-type'], 'application/problem+json');
        expect(response.headers['x-request-id'], isNotNull);
        expect(response.headers['x-content-type-options'], 'nosniff');
      }
    });

    test('a filter can change the request', () async {
      final client = WinterTestClient.build(
        globalFilterConfig: FilterConfig([_ChangeRequest()]),
        router: WinterRouter(
          routes: [Route.get(path: '/users', handler: ok)],
        ),
      );

      expect((await client.get('//users')).statusCode, 404);
    });
  });

  group('A broken route table fails at start (§9.2)', () {
    test('an invalid path', () {
      expect(
        () => WinterRouter(
          routes: [Route.get(path: '/in valid', handler: ok)],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('/in valid is not a valid URL'),
          ),
        ),
      );
    });

    test('a duplicated route, also when it is added later', () {
      final router = WinterRouter(
        routes: [Route.get(path: '/a', handler: ok)],
      );

      expect(
        () => WinterRouter(
          routes: [
            Route.get(path: '/a', handler: ok),
            Route.get(path: '/a', handler: ok),
          ],
        ),
        throwsStateError,
      );
      expect(
        () => router.addRoute(Route.get(path: '/a/', handler: ok)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            startsWith('GET /a (key: '),
          ),
        ),
      );
    });
  });

  group('Paths and duplicates (§9.3)', () {
    test('a param with a regex is a valid route', () async {
      final client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.get(
              path: r'/numbers/{id|[0-9]+}',
              handler: (r) => ResponseEntity.ok(body: r.pathParams['id']),
            ),
            Route.get(path: r'/codes/{code|[A-Z]+\d?}', handler: ok),
            Route.get(path: '/files/.*', handler: ok),
          ],
        ),
      );

      expect((await client.get('/numbers/12')).body, '12');
      expect((await client.get('/numbers/ab')).statusCode, 404);
      expect((await client.get('/codes/ABC1')).statusCode, 200);
      expect((await client.get('/files/a/b.txt')).statusCode, 200);
    });

    test('isValidUri only looks at the literal parts', () {
      expect(isValidUri(r'/n/{id|[0-9]+}'), isTrue);
      expect(isValidUri('/files/.*'), isTrue);
      expect(isValidUri('/a/(b|c)'), isTrue);
      expect(isValidUri('/in valid/{id}'), isFalse);
      expect(isValidUri('//a'), isFalse);
      expect(isValidUri('/ñ'), isFalse);
    });

    test('the same method and shape is a duplicate', () {
      final duplicated = <String>[];
      final router = WinterRouter(
        config: RouterConfig(
          onDuplicatedRoute: (route) => duplicated.add(route.path),
        ),
        routes: [
          Route.get(path: '/users/{id}', handler: ok),
          Route.get(path: '/users/{name}', handler: ok),
          Route.get(path: '/x', handler: ok, key: 'one'),
          Route.get(path: '/x', handler: ok, key: 'two'),
          Route.get(path: '/n/{id|[0-9]+}', handler: ok),
          Route.get(path: '/n/{name|[0-9]+}', handler: ok),
        ],
      );

      expect(duplicated, ['/users/{name}', '/x', '/n/{name|[0-9]+}']);
      expect(router.routes, hasLength(3));
    });

    test('other methods or another regex are not duplicates', () {
      final router = WinterRouter(
        routes: [
          Route.get(path: '/users/{id}', handler: ok),
          Route.delete(path: '/users/{id}', handler: ok),
          Route.get(path: '/n/{id|[0-9]+}', handler: ok),
          Route.get(path: '/n/{id|[a-z]+}', handler: ok),
        ],
      );

      expect(router.routes, hasLength(4));
    });

    test('a filter recognizes a route by its key', () async {
      final client = WinterTestClient.build(
        globalFilterConfig: FilterConfig([_OnlyKey('health')]),
        router: WinterRouter(
          routes: [
            Route.get(path: '/health', handler: ok, key: 'health'),
            Route.get(path: '/other', handler: ok),
          ],
        ),
      );

      expect((await client.get('/health')).headers['x-key'], 'health');
      expect((await client.get('/other')).headers, isNot(contains('x-key')));
    });
  });

  group('OPTIONS (§9.4)', () {
    final router = WinterRouter(
      routes: [
        Route.get(path: '/users', handler: ok),
        Route.post(path: '/users', handler: ok),
        Route(
          path: '/custom',
          method: HttpMethod.options,
          handler: (r) => ResponseEntity.ok(body: 'mine'),
        ),
      ],
    );
    final client = WinterTestClient.build(router: router);

    test('a path that exists is a 204 with Allow', () async {
      final response = await client.request('OPTIONS', '/users');

      expect(response.statusCode, 204);
      expect(response.body, isEmpty);
      expect(response.headers['allow'], 'GET, POST, HEAD, OPTIONS');
    });

    test('a path that does not exist is a 404', () async {
      expect((await client.request('OPTIONS', '/missing')).statusCode, 404);
    });

    test('a route of the app wins', () async {
      expect((await client.request('OPTIONS', '/custom')).body, 'mine');
    });

    test('Allow lists OPTIONS in a 405', () async {
      final response = await client.delete('/users');

      expect(response.statusCode, 405);
      expect(response.headers['allow'], 'GET, POST, HEAD, OPTIONS');
    });

    test('a MultiRouter answers it too', () async {
      final client = WinterTestClient.build(
        router: MultiRouter([
          WinterRouter(
            routes: [Route.get(path: '/a', handler: ok)],
          ),
          WinterRouter(
            routes: [Route.post(path: '/a', handler: ok)],
          ),
        ]),
      );

      final response = await client.request('OPTIONS', '/a');

      expect(response.statusCode, 204);
      expect(response.headers['allow'], 'GET, HEAD, OPTIONS, POST');
    });

    test('a CORS preflight is still answered by CorsFilter', () async {
      final client = WinterTestClient.build(
        securityConfig: SecurityConfig(cors: const CorsConfig()),
        router: router,
      );

      final response = await client.request(
        'OPTIONS',
        '/users',
        headers: {
          'origin': 'https://app.example',
          'access-control-request-method': 'POST',
        },
      );

      expect(response.headers['access-control-allow-methods'], isNotNull);
    });
  });

  group('Immutable configuration (§9.5, §9.6)', () {
    test('FilterConfig cannot be changed', () {
      const config = FilterConfig([]);

      expect(
        () => config.filters.add(_ChangeRequest()),
        throwsUnsupportedError,
      );
      expect(Route.get(path: '/a', handler: ok).filterConfig.filters, isEmpty);
    });

    test('the routes of a router are read-only, addRoute validates them', () {
      final router = WinterRouter(
        basePath: '/api',
        routes: [Route.get(path: '/a', handler: ok)],
      );

      expect(
        () => router.routes.add(Route.get(path: '/b', handler: ok)),
        throwsUnsupportedError,
      );
      router.addRoute(Route.get(path: '/b', handler: ok));
      expect(router.routes.map((route) => route.path), ['/api/a', '/api/b']);
    });

    test('MultiRouter holds its routers, read-only', () {
      final inner = WinterRouter(routes: []);
      final router = MultiRouter([inner]);

      expect(router.routers, [inner]);
      expect(() => router.routers.add(inner), throwsUnsupportedError);
    });

    test('Route.toString has no closure', () {
      final route = Route.get(path: '/a', handler: ok, key: 'k');

      expect(
        route.toString(),
        'Route{key: k, method: GET, path: /a, filters: []}',
      );
      expect(
        Route.parent(path: '/p', key: 'p').toString(),
        contains('method: PARENT'),
      );
    });
  });

  group('Typed params (§9.7)', () {
    final client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/users/{id}',
            handler: (request) =>
                ResponseEntity.ok(body: {'id': request.pathParam<int>('id')}),
          ),
          Route.get(
            path: '/search',
            handler: (request) => ResponseEntity.ok(
              body: {
                'page': request.queryParam<int>('page') ?? 1,
                'price': request.queryParam<double>('price'),
                'total': request.queryParam<num>('total'),
                'active': request.queryParam<bool>('active'),
                'since': request.queryParam<DateTime>('since'),
                'q': request.queryParam<String>('q'),
                'status': request.queryParam('status', values: _Status.values),
                'sort': request.queryParam('sort', values: ['asc', 'desc']),
              },
            ),
          ),
          Route.get(
            path: '/typo/{id}',
            handler: (request) =>
                ResponseEntity.ok(body: request.pathParam<int>('userId')),
          ),
          Route.get(
            path: '/unsupported',
            handler: (request) =>
                ResponseEntity.ok(body: '${request.queryParam<Duration>('d')}'),
          ),
        ],
      ),
    );

    Future<Map<String, Object?>> json(String path) async =>
        jsonDecode((await client.get(path)).body) as Map<String, Object?>;

    test('a path param with its type', () async {
      expect(await json('/users/42'), {'id': 42});
    });

    test(
      'a value of another type is a 400 that names the param, not the value',
      () async {
        final response = await client.get('/users/abc');

        expect(response.statusCode, 400);
        expect(response.headers['content-type'], 'application/problem+json');
        final body = jsonDecode(response.body) as Map<String, Object?>;
        expect(body['detail'], 'The path param id must be an integer');
      },
    );

    test('every supported type', () async {
      final body = await json(
        '/search?page=2&price=9.5&total=3&active=TRUE&since=2026-10-07T10:00:00Z'
        '&q=dart&status=Active&sort=desc',
      );

      expect(body, {
        'page': 2,
        'price': 9.5,
        'total': 3,
        'active': true,
        'since': '2026-10-07T10:00:00.000Z',
        'q': 'dart',
        'status': 'active',
        'sort': 'desc',
      });
    });

    test('a missing or empty query param is null', () async {
      final body = await json('/search?page=&q=');

      expect(body['page'], 1);
      expect(body['q'], isNull);
      expect(body['status'], isNull);
    });

    test('the errors of every type', () async {
      final cases = {
        '/search?page=1.5': 'The query param page must be an integer',
        '/search?price=x': 'The query param price must be a number',
        '/search?total=x': 'The query param total must be a number',
        '/search?active=yes': 'The query param active must be true or false',
        '/search?since=yesterday':
            'The query param since must be an ISO 8601 date',
        '/search?status=gone':
            'The query param status must be one of: active, blocked',
        '/search?sort=up': 'The query param sort must be one of: asc, desc',
      };
      for (final MapEntry(key: path, value: detail) in cases.entries) {
        final response = await client.get(path);

        expect(response.statusCode, 400, reason: path);
        expect(
          (jsonDecode(response.body) as Map<String, Object?>)['detail'],
          detail,
        );
      }
    });

    test(
      'a param that is not in the route, or an unsupported type, is a 500',
      () async {
        expect((await client.get('/typo/1')).statusCode, 500);
        expect((await client.get('/unsupported?d=1s')).statusCode, 500);
      },
    );

    test('the errors of the app are thrown as they are', () {
      final request = RequestEntity('GET', Uri.parse('http://localhost/?d=1'));

      expect(() => request.pathParam<int>('id'), throwsStateError);
      expect(() => request.queryParam<Duration>('d'), throwsArgumentError);
    });
  });

  group('Responses (§9.8)', () {
    final client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.post(
            path: '/users',
            handler: (r) =>
                ResponseEntity.created(location: '/users/1', body: {'id': 1}),
          ),
          Route.post(path: '/plain', handler: (r) => ResponseEntity.created()),
          Route.post(
            path: '/jobs',
            handler: (r) => ResponseEntity.accepted(body: {'job': 7}),
          ),
          Route.delete(
            path: '/users/{id}',
            handler: (r) => ResponseEntity.noContent(),
          ),
          Route.get(path: '/gone', handler: (r) => ResponseEntity.notFound()),
        ],
      ),
    );

    test('created has a Location', () async {
      final response = await client.post('/users');

      expect(response.statusCode, 201);
      expect(response.headers['location'], '/users/1');
      expect(jsonDecode(response.body), {'id': 1});

      final plain = await client.post('/plain');
      expect(plain.statusCode, 201);
      expect(plain.headers, isNot(contains('location')));
    });

    test('accepted and noContent', () async {
      expect((await client.post('/jobs')).statusCode, 202);

      final noContent = await client.delete('/users/1');
      expect(noContent.statusCode, 204);
      expect(noContent.body, isEmpty);
    });

    test('every error shortcut has its status', () {
      expect(
        [
          ResponseEntity<void>.badRequest(),
          ResponseEntity<void>.unauthorized(),
          ResponseEntity<void>.forbidden(),
          ResponseEntity<void>.notFound(),
          ResponseEntity<void>.methodNotAllowed(),
          ResponseEntity<void>.tooManyRequests(retryAfter: 3),
          ResponseEntity<void>.internalServerError(),
        ].map((response) => response.statusCode),
        [400, 401, 403, 404, 405, 429, 500],
      );
      expect(
        ResponseEntity<void>.tooManyRequests(retryAfter: 3)
            .headers['retry-after'],
        '3',
      );
    });

    test('an error shortcut without a body sends none', () async {
      final response = await client.get('/gone');

      expect(response.statusCode, 404);
      expect(response.body, isEmpty);
    });
  });
}

enum _Status { active, blocked }

class _ChangeRequest extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async => chain.doFilter(request.change(headers: {'x-changed': 'yes'}));
}

/// Marks the response of the route with the [key]
class _OnlyKey extends Filter {
  final String key;

  _OnlyKey(this.key);

  @override
  bool shouldFilter(RequestEntity request) =>
      request.routingContext?.key == key;

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final response = await chain.doFilter(request);
    return response.change(headers: {'x-key': key});
  }
}
