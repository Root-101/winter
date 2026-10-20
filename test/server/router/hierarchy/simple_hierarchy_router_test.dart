@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(() async {
    client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route(
            path: '/parent',
            routes: [
              Route(
                path: '/child-1',
                method: HttpMethod.get,
                handler: (request) => ResponseEntity.ok(
                  body: 'Return from response /parent/child-1',
                ),
              ),
              Route(
                path: '/child-2',
                method: HttpMethod.get,
                handler: (request) => ResponseEntity.ok(
                  body: 'Return from response /parent/child-2',
                ),
              ),
            ],
          ),
          Route(
            path: '/single-route',
            method: HttpMethod.get,
            handler: (request) =>
                ResponseEntity.ok(body: 'Return from response /single-route'),
          ),
          Route(
            path: '/route-parent',
            method: HttpMethod.get,
            handler: (request) =>
                ResponseEntity.ok(body: 'Return from response /route-parent'),
            routes: [
              Route(
                path: '/child',
                method: HttpMethod.get,
                handler: (request) => ResponseEntity.ok(
                  body: 'Return from response /route-parent/child',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  });

  test(
    'each child of a parent without a handler has the joined path',
    () async {
      for (final String child in ['child-1', 'child-2']) {
        final TestResponse response = await client.get('/parent/$child');

        expect(response.statusCode, 200);
        expect(response.body, 'Return from response /parent/$child');
      }
    },
  );

  test('a route without children next to the parents', () async {
    String urlToTest = '/single-route';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /single-route');
  });

  test('a parent with a handler answers its own path', () async {
    String urlToTest = '/route-parent';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /route-parent');
  });

  test('the child of a parent with a handler has its own handler', () async {
    String urlToTest = '/route-parent/child';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /route-parent/child');
  });
}
