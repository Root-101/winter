import 'package:test/test.dart';

import '../../../../bin/winter/winter.dart';

void main() {
  int port = 9090;

  bool failed = false;
  setUp(
    () async {
      try {
        await Winter.run(
          config: ServerConfig(port: port),
          router: HRouter(
            config: RouterConfig(
              onInvalidUrl: (failedRoute) {
                throw Exception(
                  '${failedRoute.path} is not a valid URL. Failing to start app',
                );
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

  test('Test fail', () async {
    expect(failed, true);
  });
}
