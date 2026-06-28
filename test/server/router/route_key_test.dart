@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('Test Route key', () {
    int port = 9080;
    String localUrl = 'http://localhost:$port';

    setUp(() async {
      await Winter.start(
        config: ServerConfig(port: port),
        router: WinterRouter(
          routes: [
            Route(
              key: 'test-key',
              path: '/test',
              method: HttpMethod.get,
              handler: (request) async {
                return ResponseEntity.ok(
                  body: request.routingContext?.key ?? '',
                );
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

    tearDownAll(() => Winter.close(force: true));

    Uri url(String path) => Uri.parse(localUrl + path);

    test('Retrieve correct key', () async {
      String urlToTest = '/test';

      http.Response response = await http.get(url(urlToTest));

      expect(response.statusCode, 200);
      expect(response.body, 'test-key');
    });
  });
}
