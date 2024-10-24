@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../../bin/winter.dart';

void main() {
  int port = 9041;
  String localUrl = 'http://localhost:$port';

  setUpAll(
    () async {
      await Winter.run(
        config: ServerConfig(port: port),
        router: WinterRouter(
          routes: [
            Route(
              path: '/get-method',
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(
                body: 'Response from get-method',
              ),
            ),
            Route(
              path: '/post-method',
              method: HttpMethod.post,
              handler: (request) => ResponseEntity.ok(
                body: 'Response from post-method',
              ),
            ),
            Route(
              path: '/put-method',
              method: HttpMethod.put,
              handler: (request) => ResponseEntity.ok(
                body: 'Response from put-method',
              ),
            ),
            Route(
              path: '/delete-method',
              method: HttpMethod.delete,
              handler: (request) => ResponseEntity.ok(
                body: 'Response from delete-method',
              ),
            ),
            Route(
              path: '/patch-method',
              method: HttpMethod.patch,
              handler: (request) => ResponseEntity.ok(
                body: 'Response from patch-method',
              ),
            ),
            Route(
              path: '/query-method',
              method: HttpMethod.query,
              handler: (request) => ResponseEntity.ok(
                body: 'Response from query-method',
              ),
            ),
            Route(
              path: '/custom-method',
              method: const HttpMethod('custom'),
              handler: (request) => ResponseEntity.ok(
                body: 'Response from custom-method',
              ),
            ),
          ],
        ),
      );
    },
  );

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Get-Method', () async {
    String urlToTest = '/get-method';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from get-method');
  });

  test('Post-Method', () async {
    String urlToTest = '/post-method';
    http.Response response = await http.post(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from post-method');
  });

  test('Put-Method', () async {
    String urlToTest = '/put-method';
    http.Response response = await http.put(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from put-method');
  });

  test('Delete-Method', () async {
    String urlToTest = '/delete-method';
    http.Response response = await http.delete(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from delete-method');
  });

  test('Patch-Method', () async {
    String urlToTest = '/patch-method';
    http.Response response = await http.patch(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from patch-method');
  });

  test('405: Method not allowed', () async {
    String urlToTest = '/get-method';
    http.Response response = await http.post(url(urlToTest));

    expect(response.statusCode, 405);
  });

  test('404: Not found', () async {
    String urlToTest = '/some-other-method';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 404);
  });

  /*//TODO: query, custom
  test('Custom-Method', () async {
    String urlToTest = '/custom-method';
    http.Response response = await http.put(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Response from custom-method');
  });*/
}
