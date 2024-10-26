@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9040;

  bool failed = false;
  setUpAll(
    () async {
      try {
        await Winter.run(
          config: ServerConfig(port: port),
          router: WinterRouter(
            config: RouterConfig(
              onInvalidUrl: (failedRoute) => throw Exception(
                '${failedRoute.path} is not a valid URL. Failing to start app',
              ),
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

  test('Test fail', () async {
    expect(failed, true);
  });
}
