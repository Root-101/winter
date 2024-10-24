@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../../bin/winter.dart';

void main() {
  int port = 9045;
  String localUrl = 'http://localhost:$port';

  setUpAll(
    () async {
      await Winter.run(
        config: ServerConfig(port: port),
        router: WinterRouter(
          routes: [
            Route(
              path: '/test',
              method: HttpMethod.get,
              handler: (request) async {
                return ResponseEntity.ok(body: 'Response from /test');
              },
            ),
            Route(
              path: '/custom',
              method: HttpMethod.post,
              handler: (request) async {
                return ResponseEntity.ok(body: 'Response from /custom');
              },
            ),
            Route(
              path: '/.*',
              method: HttpMethod.post,
              handler: (request) async {
                return ResponseEntity.ok(
                  body: 'Response from any other source',
                );
              },
            ),
          ],
        ),
      );
    },
  );

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test /test', () async {
    String urlToTest = '/test';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from /test');
  });

  test('Test /custom', () async {
    String urlToTest = '/custom';
    http.Response response = await http.post(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from /custom');
  });

  test('Test other sources #1', () async {
    String urlToTest = '/abc';
    http.Response response = await http.post(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from any other source');
  });

  test('Test other sources #2', () async {
    String urlToTest = '/123';
    http.Response response = await http.post(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from any other source');
  });

  test('Test other sources #3', () async {
    String urlToTest = '/some-other';
    http.Response response = await http.post(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from any other source');
  });

  test('Test other sources #4', () async {
    String urlToTest = '/f-r-i-e-n-d-s';
    http.Response response = await http.post(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from any other source');
  });
}
