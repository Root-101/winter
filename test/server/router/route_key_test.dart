@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;
  group('Test Route key', () {
    setUp(() async {
      client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route(
              key: 'test-key',
              path: '/test',
              method: HttpMethod.get,
              handler: (request) async {
                return ResponseEntity.ok(body: request.route?.key ?? '');
              },
            ),
            Route(
              path: '/random-key',
              method: HttpMethod.get,
              handler: (request) async {
                return ResponseEntity.ok(body: 'hello world!!!');
              },
            ),
          ],
        ),
      );
    });

    test('Retrieve correct key', () async {
      String urlToTest = '/test';

      TestResponse response = await client.get(urlToTest);

      expect(response.statusCode, 200);
      expect(response.body, 'test-key');
    });
  });
}
