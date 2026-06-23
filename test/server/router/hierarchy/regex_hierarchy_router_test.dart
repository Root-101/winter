@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9052;
  String localUrl = 'http://localhost:$port';

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port),
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

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test /parent.*/child-1', () async {
    String urlToTest = '/parent_hello_world/child-1';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /parent/child-1');
  });

  test('Test /parent.*/child-2', () async {
    String urlToTest = '/parent_hi/child-2';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /parent/child-2');
  });

  test('Test /single-route.* #1', () async {
    String urlToTest = '/single-route-alleluia';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /single-route');
  });

  test('Test /single-route.* #2', () async {
    String urlToTest = '/single-route/bye';
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
    String urlToTest = '/route-parent/child_123546789';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /route-parent/child');
  });
}
