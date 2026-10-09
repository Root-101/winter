@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(() async {
    client = WinterTestClient.build(
      router: MultiRouter([
        WinterRouter(
          routes: [
            Route(
              path: '/test',
              method: HttpMethod.get,
              handler: (request) async {
                return ResponseEntity.ok(body: 'Response from /test');
              },
            ),
          ],
        ),
        ServeRouter(
          (request) => ResponseEntity.ok(body: 'Response from hierarchy #2'),
        ),
        WinterRouter(
          routes: [
            Route(
              path: '/users',
              method: HttpMethod.get,
              handler: (request) async {
                return ResponseEntity.ok(body: 'Response from /users');
              },
            ),
          ],
        ),
      ]),
    );
  });

  test('Test Router #1 => /test', () async {
    String urlToTest = '/test';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from /test');
  });

  test('Test Router #2 => /other', () async {
    String urlToTest = '/other';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from hierarchy #2');
  });

  test('Test Router #2 => /other-123', () async {
    String urlToTest = '/other-123';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from hierarchy #2');
  });

  //This actually call hierarchy #2 because serve handle all request and never gets to hierarchy #3
  test('Test Router #3 => /users', () async {
    String urlToTest = '/users';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from hierarchy #2');
  });
}
