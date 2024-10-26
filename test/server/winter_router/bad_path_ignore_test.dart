@TestOn('vm')
library;

import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9041;
  String localUrl = 'http://localhost:$port';

  bool failed = false;
  setUpAll(
    () async {
      try {
        await Winter.run(
          config: ServerConfig(port: port),
          router: WinterRouter(
            config: RouterConfig(
              onInvalidUrl: (failedRoute) =>
                  log('${failedRoute.path} is not a valid URL. Ignoring'),
            ),
            routes: [
              Route(
                path: '/test - asdt',
                method: HttpMethod.get,
                handler: (request) async {
                  return ResponseEntity.ok(
                    body: 'hello world!!!',
                  );
                },
              ),
            ],
          ),
        );
        failed = false;
      } catch (_) {
        failed = true;
      }
    },
  );

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test fail', () async {
    expect(failed, false);
  });

  test('Test /test - asdt', () async {
    String urlToTest = '/test - asdt';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 404);
  });
}
