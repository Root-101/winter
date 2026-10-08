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

  test('Test /parent.*/child-1', () async {
    String urlToTest = '/parent_hello_world/child-1';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /parent/child-1');
  });

  test('Test /parent.*/child-2', () async {
    String urlToTest = '/parent_hi/child-2';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /parent/child-2');
  });

  test('Test /single-route.* #1', () async {
    String urlToTest = '/single-route-alleluia';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /single-route');
  });

  test('Test /single-route.* #2', () async {
    String urlToTest = '/single-route/bye';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /single-route');
  });

  test('Test /route-parent', () async {
    String urlToTest = '/route-parent';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /route-parent');
  });

  test('Test /route-parent/child', () async {
    String urlToTest = '/route-parent/child_123546789';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /route-parent/child');
  });
}
