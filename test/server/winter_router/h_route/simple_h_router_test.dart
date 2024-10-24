@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9052;
  String localUrl = 'http://localhost:$port';

  setUpAll(
    () async {
      await Winter.run(
        config: ServerConfig(port: port),
        router: HRouter(
          routes: [
            ParentRoute(
              path: '/parent',
              routes: [
                HRoute(
                  path: '/child-1',
                  method: HttpMethod.get,
                  handler: (request) => ResponseEntity.ok(
                    body: 'Return from response /parent/child-1',
                  ),
                ),
                HRoute(
                  path: '/child-2',
                  method: HttpMethod.get,
                  handler: (request) => ResponseEntity.ok(
                    body: 'Return from response /parent/child-2',
                  ),
                ),
              ],
            ),
            HRoute(
              path: '/single-route',
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(
                body: 'Return from response /single-route',
              ),
            ),
            HRoute(
              path: '/route-parent',
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(
                body: 'Return from response /route-parent',
              ),
              routes: [
                HRoute(
                  path: '/child',
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
    },
  );

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test /parent/child-1', () async {
    String urlToTest = '/parent/child-1';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /parent/child-1');
  });

  test('Test /parent/child-2', () async {
    String urlToTest = '/parent/child-2';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /parent/child-2');
  });

  test('Test /single-route', () async {
    String urlToTest = '/single-route';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /single-route');
  });

  test('Test /route-parent', () async {
    String urlToTest = '/route-parent';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /route-parent');
  });

  test('Test /route-parent/child', () async {
    String urlToTest = '/route-parent/child';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /route-parent/child');
  });
}
