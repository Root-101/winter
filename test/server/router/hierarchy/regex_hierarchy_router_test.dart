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
            path: '/parent.*',
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
            path: '/single-route.*',
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
                path: '/child.*',
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

  test('the regex of a parent matches before each child', () async {
    for (final (String url, String child) in [
      ('/parent_hello_world/child-1', 'child-1'),
      ('/parent_hi/child-2', 'child-2'),
    ]) {
      final TestResponse response = await client.get(url);

      expect(response.statusCode, 200, reason: url);
      expect(response.body, 'Return from response /parent/$child');
    }
  });

  test('a regex route matches any rest of the path, / included', () async {
    for (final String url in ['/single-route-alleluia', '/single-route/bye']) {
      final TestResponse response = await client.get(url);

      expect(response.statusCode, 200, reason: url);
      expect(response.body, 'Return from response /single-route');
    }
  });

  test('a regex child after a static parent', () async {
    String urlToTest = '/route-parent/child_123546789';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /route-parent/child');
  });
}
