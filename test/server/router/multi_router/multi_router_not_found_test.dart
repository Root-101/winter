@TestOn('vm')
library;

import 'package:test/test.dart';

import 'dart:async';

import 'package:winter/winter.dart';

/// A router that never handles anything (and has no routes to allow)
class _NeverRouter extends BaseRouter {
  @override
  bool canHandle(RequestEntity request) => false;

  @override
  FutureOr<ResponseEntity> handler(RequestEntity request) =>
      ResponseEntity.ok();
}

void main() {
  late WinterTestClient client;

  setUpAll(() async {
    client = WinterTestClient.build(
      router: MultiRouter([
        WinterRouter(
          routes: [
            Route.get(
              path: '/users',
              handler: (request) => ResponseEntity.ok(body: 'users'),
            ),
          ],
        ),
        MultiRouter([
          WinterRouter(
            routes: [
              Route.post(
                path: '/items/{id}',
                handler: (request) => ResponseEntity.ok(body: 'item'),
              ),
            ],
          ),
        ]),
      ]),
    );
  });

  test('Matching route still works', () async {
    final response = await client.get('/users');

    expect(response.statusCode, 200);
    expect(response.body, 'users');
  });

  test('Unknown path returns 404', () async {
    final response = await client.get('/unknown');

    expect(response.statusCode, 404);
    expect(response.body, isNot(contains('Bad state')));
  });

  test('Known path with wrong method returns 405', () async {
    final response = await client.delete('/users');

    expect(response.statusCode, 405);
  });

  test(
    'Known path with wrong method in a nested MultiRouter returns 405',
    () async {
      final response = await client.get('/items/42');

      expect(response.statusCode, 405);
    },
  );

  test('A custom router inside a MultiRouter does not break the 404', () async {
    final client = WinterTestClient.build(
      router: MultiRouter([_NeverRouter(), WinterRouter(routes: [])]),
    );

    expect((await client.get('/anything')).statusCode, 404);
  });
}
