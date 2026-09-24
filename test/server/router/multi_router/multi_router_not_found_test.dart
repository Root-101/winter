@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9062;
  String localUrl = 'http://localhost:$port';

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port),
      router: MultiRouter([
        WinterRouter(
          routes: [
            Route.get(
              path: '/users',
              handler: (request) => ResponseEntity.ok(body: 'users'),
            ),
          ],
        ),
        MultiRouter([
          WinterRouter(
            routes: [
              Route.post(
                path: '/items/{id}',
                handler: (request) => ResponseEntity.ok(body: 'item'),
              ),
            ],
          ),
        ]),
      ]),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Matching route still works', () async {
    final response = await http.get(url('/users'));

    expect(response.statusCode, 200);
    expect(response.body, 'users');
  });

  test('Unknown path returns 404', () async {
    final response = await http.get(url('/unknown'));

    expect(response.statusCode, 404);
    expect(response.body, isNot(contains('Bad state')));
  });

  test('Known path with wrong method returns 405', () async {
    final response = await http.delete(url('/users'));

    expect(response.statusCode, 405);
  });

  test(
    'Known path with wrong method in a nested MultiRouter returns 405',
    () async {
      final response = await http.get(url('/items/42'));

      expect(response.statusCode, 405);
    },
  );
}
