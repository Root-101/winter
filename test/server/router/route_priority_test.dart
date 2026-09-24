@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9066;
  String localUrl = 'http://localhost:$port';

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port),
      router: MultiRouter([
        WinterRouter(
          routes: [
            ///Declared before the static one on purpose
            Route.get(
              path: '/users/{id}',
              handler: (request) =>
                  ResponseEntity.ok(body: 'user ${request.pathParams['id']}'),
            ),
            Route.get(
              path: '/users/me',
              handler: (request) => ResponseEntity.ok(body: 'me'),
            ),
            Route.delete(
              path: '/users/{id}',
              handler: (request) => ResponseEntity.ok(body: 'deleted'),
            ),
          ],
        ),
        WinterRouter(
          routes: [
            Route.post(
              path: '/items',
              handler: (request) => ResponseEntity.ok(body: 'created'),
            ),
          ],
        ),
      ]),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Static route wins over a param route declared before', () async {
    final response = await http.get(url('/users/me'));

    expect(response.statusCode, 200);
    expect(response.body, 'me');
  });

  test('Param route still handles the other paths', () async {
    final response = await http.get(url('/users/42'));

    expect(response.statusCode, 200);
    expect(response.body, 'user 42');
  });

  test('Path params are url-decoded', () async {
    final response = await http.get(url('/users/John%20Doe'));

    expect(response.body, 'user John Doe');
  });

  test('405 includes the Allow header', () async {
    final response = await http.put(url('/users/42'));

    expect(response.statusCode, 405);
    expect(response.headers['allow'], 'GET, DELETE');
  });

  test('405 from another router of the MultiRouter includes Allow', () async {
    final response = await http.get(url('/items'));

    expect(response.statusCode, 405);
    expect(response.headers['allow'], 'POST');
  });

  test('Unknown path is still a 404 without Allow', () async {
    final response = await http.get(url('/unknown'));

    expect(response.statusCode, 404);
    expect(response.headers.containsKey('allow'), isFalse);
  });

  group('WinterRouter (unit)', () {
    RequestEntity request(String method, String path) =>
        RequestEntity(method, Uri.parse('http://localhost$path'));

    final router = WinterRouter(
      routes: [
        Route.get(path: '/a/{x}', handler: (r) => ResponseEntity.ok()),
        Route.get(path: '/a/.*', handler: (r) => ResponseEntity.ok()),
        Route.get(path: '/a/b', handler: (r) => ResponseEntity.ok()),
      ],
    );

    test('Static route has priority over params and regex', () {
      expect(router.handlerRoute(request('GET', '/a/b'))!.path, '/a/b');
    });

    test('Between dynamic routes the first declared wins', () {
      expect(router.handlerRoute(request('GET', '/a/c'))!.path, '/a/{x}');
    });

    test('isStatic', () {
      expect(
        Route.get(path: '/a/b', handler: (r) => ResponseEntity.ok()).isStatic,
        isTrue,
      );
      expect(
        Route.get(path: '/a/{x}', handler: (r) => ResponseEntity.ok()).isStatic,
        isFalse,
      );
      expect(
        Route.get(path: '/.*', handler: (r) => ResponseEntity.ok()).isStatic,
        isFalse,
      );
    });
  });
}
