@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9060;
  String localUrl = 'http://localhost:$port';

  setUpAll(
    () async {
      await Winter.run(
        config: ServerConfig(port: port),
        router: MultiRouter(
          [
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
              (request) => ResponseEntity.ok(body: 'Response from router #2'),
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
          ],
        ),
      );
    },
  );

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test Router #1 => /test', () async {
    String urlToTest = '/test';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from /test');
  });

  test('Test Router #2 => /other', () async {
    String urlToTest = '/other';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from router #2');
  });

  test('Test Router #2 => /other-123', () async {
    String urlToTest = '/other-123';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from router #2');
  });

  //This actually call router #2 because serve handle all request and never gets to router #3
  test('Test Router #3 => /users', () async {
    String urlToTest = '/users';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from router #2');
  });
}
