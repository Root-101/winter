@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(() async {
    WinterRouter router = WinterRouter(
      routes: [
        Route(
          path: '/test',
          method: HttpMethod.get,
          handler: (request) async {
            return ResponseEntity.ok(body: 'Response from /test');
          },
        ),
      ],
    );
    router.addRoute(
      Route.post(
        path: '/custom',
        handler: (request) async {
          return ResponseEntity.ok(body: 'Response from /custom');
        },
      ),
    );
    router.addRoute(
      Route(
        path: '/.*',
        method: HttpMethod.post,
        handler: (request) async {
          return ResponseEntity.ok(body: 'Response from any other source');
        },
      ),
    );
    client = WinterTestClient.build(router: router);
  });

  test('Test /test', () async {
    String urlToTest = '/test';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from /test');
  });

  test('Test /custom', () async {
    String urlToTest = '/custom';
    TestResponse response = await client.post(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from /custom');
  });

  test('Test other sources #1', () async {
    String urlToTest = '/abc';
    TestResponse response = await client.post(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from any other source');
  });

  test('Test other sources #2', () async {
    String urlToTest = '/123';
    TestResponse response = await client.post(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from any other source');
  });

  test('Test other sources #3', () async {
    String urlToTest = '/some-other';
    TestResponse response = await client.post(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from any other source');
  });

  test('Test other sources #4', () async {
    String urlToTest = '/f-r-i-e-n-d-s';
    TestResponse response = await client.post(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from any other source');
  });
}
