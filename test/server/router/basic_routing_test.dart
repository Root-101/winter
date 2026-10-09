@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The same routes, declared in the constructor or added later with addRoute
void main() {
  Route testRoute = Route.get(
    path: '/test',
    handler: (request) => ResponseEntity.ok(body: 'Response from /test'),
  );
  Route custom = Route.post(
    path: '/custom',
    handler: (request) => ResponseEntity.ok(body: 'Response from /custom'),
  );
  Route any = Route.post(
    path: '/.*',
    handler: (request) => ResponseEntity.ok(body: 'Any other path'),
  );

  final Map<String, WinterRouter Function()> routers = {
    'constructor': () => WinterRouter(routes: [testRoute, custom, any]),
    'addRoute': () => WinterRouter(routes: [testRoute])
      ..addRoute(custom)
      ..addRoute(any),
  };

  for (final MapEntry(key: how, value: router) in routers.entries) {
    group('Routes from the $how', () {
      final client = WinterTestClient.build(router: router());

      test('a GET and a POST route', () async {
        expect((await client.get('/test')).body, 'Response from /test');
        expect((await client.post('/custom')).body, 'Response from /custom');
      });

      test('a regex route takes every other POST', () async {
        for (final path in ['/abc', '/123', '/some-other', '/f-r-i-e-n-d-s']) {
          final response = await client.post(path);

          expect(response.statusCode, 200, reason: path);
          expect(response.body, 'Any other path', reason: path);
        }
      });
    });
  }
}
