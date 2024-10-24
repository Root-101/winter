@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9043;
  String localUrl = 'http://localhost:$port';

  setUpAll(
    () async {
      await Winter.run(
        config: ServerConfig(port: port),
        router: WinterRouter(
          routes: [
            Route(
              path: '/test_.*',
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(
                body: 'test',
              ),
            ),
            Route(
              path: '/hi_.*/{id}',
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(
                body: request.pathParams['id'],
              ),
            ),
            Route(
              path: '/anything.*',
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(
                body: request.url,
              ),
            ),
          ],
        ),
      );
    },
  );

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test /test_(any) #1', () async {
    String urlToTest = '/test_1';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);

    expect(response.body, 'test');
  });

  test('Test /test_(any) #2', () async {
    String urlToTest = '/test_abcdef';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);

    expect(response.body, 'test');
  });

  test('Test /hi_(any)/{id} #1', () async {
    String urlToTest = '/hi_abcdef/123';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);

    expect(response.body, '123');
  });

  test('Test /hi_(any)/{id} #2', () async {
    String urlToTest = '/hi_123456/abc';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);

    expect(response.body, 'abc');
  });

  test('Test /hi_(any)/{id} #3', () async {
    String urlToTest = '/hi_abcdef';

    ///without the /{id} param
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 404);
  });

  test('Test /anything.* #1', () async {
    String urlToTest = '/anything';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'anything');
  });

  test('Test /anything.* #2', () async {
    String urlToTest = '/anything/test';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'anything/test');
  });

  test('Test some other url', () async {
    String urlToTest = '/hello/my/friend';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 404);
  });
}
