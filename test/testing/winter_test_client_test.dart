import 'dart:async';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

class _Item {
  final String name;

  _Item(this.name);
  Object? toJson() => {'name': name};
}

/// Authenticates the request when the header 'X-User' is present
class _HeaderAuthFilter extends Filter {
  @override
  FutureOr<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) {
    final user = request.headers['X-User'];
    if (user != null) {
      request.securityContext.setAuthentication(
        Authentication(principal: user),
      );
    }
    return chain.doFilter(request);
  }
}

void main() {
  late WinterTestClient client;

  setUp(() {
    client = WinterTestClient.build(
      securityConfig: SecurityConfig(cors: const CorsConfig()),
      globalFilterConfig: FilterConfig([_HeaderAuthFilter()]),
      maxBodySize: 64,
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/items/{id}',
            handler: (request) => ResponseEntity.ok(
              body: _Item('item ${request.pathParams['id']}'),
            ),
          ),
          Route.post(
            path: '/items',
            handler: (request) async {
              final body = await request.body<Map<String, dynamic>>();
              return ResponseEntity(201, body: body);
            },
          ),
          Route.get(
            path: '/secret',
            handler: (request) => ResponseEntity.ok(body: 'secret'),
            filterConfig: FilterConfig([AuthFilter()]),
          ),
          Route.get(
            path: '/boom',
            handler: (request) => throw const NotFoundException(),
          ),
        ],
      ),
    );
  });

  test('works without starting a server', () async {
    final response = await client.get('/items/1');

    expect(Winter.isRunning, isFalse);
    expect(response.statusCode, 200);
    expect(response.json, {'name': 'item 1'});
    expect(response.headers['content-type'], 'application/json; charset=utf-8');
  });

  test('sends objects as JSON', () async {
    final response = await client.post('/items', body: {'name': 'new'});

    expect(response.statusCode, 201);
    expect(response.json, {'name': 'new'});
  });

  test('404, 405 & HEAD behave like a real server', () async {
    expect((await client.get('/unknown')).statusCode, 404);

    final notAllowed = await client.delete('/items/1');
    expect(notAllowed.statusCode, 405);
    expect(notAllowed.headers['allow'], 'GET, HEAD, OPTIONS');

    final head = await client.head('/items/1');
    expect(head.statusCode, 200);
    expect(head.body, isEmpty);
  });

  test('runs the filters, CORS & the exception handler', () async {
    expect((await client.get('/secret')).statusCode, 401);
    expect(
      (await client.get('/secret', headers: {'X-User': 'adam'})).body,
      'secret',
    );

    final error = await client.get(
      '/boom',
      headers: {'Origin': 'http://a.com'},
    );
    expect(error.statusCode, 404);
    expect(error.headers['access-control-allow-origin'], '*');
  });

  test('applies the body size limit', () async {
    final response = await client.post('/items', body: 'a' * 100);

    expect(response.statusCode, 413);
  });

  test('several clients can be used at the same time', () async {
    final other = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/other',
            handler: (r) => ResponseEntity.ok(body: 'other'),
          ),
        ],
      ),
    );

    final responses = await Future.wait([
      client.get('/items/1'),
      other.get('/other'),
    ]);

    expect(responses[0].statusCode, 200);
    expect(responses[1].body, 'other');
  });

  test('put & patch send the body', () async {
    final echo = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.put(
            path: '/echo',
            handler: (request) async =>
                ResponseEntity.ok(body: 'put ${await request.body<String>()}'),
          ),
          Route.patch(
            path: '/echo',
            handler: (request) async => ResponseEntity.ok(
              body: 'patch ${await request.body<String>()}',
            ),
          ),
        ],
      ),
    );

    expect((await echo.put('/echo', body: 'a')).body, 'put a');
    expect((await echo.patch('/echo', body: 'b')).body, 'patch b');
  });
}
