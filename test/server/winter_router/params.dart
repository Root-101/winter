@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../../bin/winter/winter.dart';

void main() {
  int port = 9090;
  String localUrl = 'http://localhost:$port';

  setUp(
    () async {
      await Winter.run(
        config: ServerConfig(port: port),
        router: WinterRouter(
          routes: [
            Route(
              path: '/test/{id}',
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(
                body:
                    'path: ${request.pathParams}, query: ${request.queryParams}',
              ),
            ),
          ],
        ),
      );
    },
  );

  tearDown(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Path & Query params', () async {
    String urlToTest = '/test/some-id?some-other-id=12345&more-ids=963258';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);

    expect(
      response.body,
      'path: {id: some-id}, query: {some-other-id: 12345, more-ids: 963258}',
    );
  });
}
