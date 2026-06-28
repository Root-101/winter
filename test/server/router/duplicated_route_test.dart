@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('Fail on duplicated route', () {
    int port = 9050;
    bool failed = false;

    setUpAll(() async {
      try {
        await Winter.start(
          config: ServerConfig(port: port),
          router: WinterRouter(
            config: RouterConfig(
              onDuplicatedRoute: DefaultOnDuplicatedRoute.fail(),
            ),
            routes: [
              Route(
                path: '/test',
                method: HttpMethod.get,
                handler: (request) async => ResponseEntity.ok(body: 'first'),
              ),
              Route(
                path: '/test',
                method: HttpMethod.get,
                handler: (request) async => ResponseEntity.ok(body: 'second'),
              ),
            ],
          ),
        );
        failed = false;
      } catch (_) {
        failed = true;
      }
    });

    tearDownAll(() => Winter.close(force: true));

    test('Test fail on duplicated route', () async {
      expect(failed, true);
    });
  });

  group('Ignore duplicated route', () {
    int port = 9051;
    String localUrl = 'http://localhost:$port';
    bool failed = false;

    setUpAll(() async {
      try {
        await Winter.start(
          config: ServerConfig(port: port),
          router: WinterRouter(
            config: RouterConfig(
              onDuplicatedRoute: DefaultOnDuplicatedRoute.ignore(log: false),
            ),
            routes: [
              Route(
                path: '/test',
                method: HttpMethod.get,
                handler: (request) async => ResponseEntity.ok(body: 'first'),
              ),
              Route(
                path: '/test',
                method: HttpMethod.get,
                handler: (request) async => ResponseEntity.ok(body: 'second'),
              ),
            ],
          ),
        );
        failed = false;
      } catch (_) {
        failed = true;
      }
    });

    tearDownAll(() => Winter.close(force: true));

    Uri url(String path) => Uri.parse(localUrl + path);

    test('Test no fail on duplicated route', () async {
      expect(failed, false);
    });

    test('Test first route is preserved', () async {
      http.Response response = await http.get(url('/test'));

      expect(response.statusCode, 200);
      expect(response.body, 'first');
    });
  });

  group('Explicit duplicate key', () {
    int port = 9052;
    bool failed = false;

    setUpAll(() async {
      try {
        await Winter.start(
          config: ServerConfig(port: port),
          router: WinterRouter(
            config: RouterConfig(
              onDuplicatedRoute: DefaultOnDuplicatedRoute.fail(),
            ),
            routes: [
              Route(
                path: '/test1',
                key: 'duplicate-key',
                method: HttpMethod.get,
                handler: (request) async => ResponseEntity.ok(body: 'first'),
              ),
              Route(
                path: '/test2',
                key: 'duplicate-key',
                method: HttpMethod.get,
                handler: (request) async => ResponseEntity.ok(body: 'second'),
              ),
            ],
          ),
        );
        failed = false;
      } catch (_) {
        failed = true;
      }
    });

    tearDownAll(() => Winter.close(force: true));

    test('Test fail on explicit duplicated key', () async {
      expect(failed, true);
    });
  });
}
