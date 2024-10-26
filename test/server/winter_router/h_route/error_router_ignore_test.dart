@TestOn('vm')
library;

import 'dart:developer';

import 'package:test/test.dart';
import 'package:winter/winter.dart';
import 'package:http/http.dart' as http;

void main() {
  int port = 9051;
  String localUrl = 'http://localhost:$port';

  bool failed = false;
  setUpAll(
    () async {
      try {
        await Winter.run(
          config: ServerConfig(port: port),
          router: HRouter(
            config: RouterConfig(
              onInvalidUrl: (failedRoute) {
                log('${failedRoute.path} is not a valid URL. Ignoring');
              },
            ),
            routes: [
              HRoute(
                path: '/single  -  route',
                method: HttpMethod.get,
                handler: (request) => ResponseEntity.ok(
                  body: 'Return from response /single-route',
                ),
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

  test('Test /single  -  route', () async {
    String urlToTest = '/single  -  route';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 404);
  });
}
