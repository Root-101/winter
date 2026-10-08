@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(() async {
    client = WinterTestClient.build(
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
  });

  test('Path & Query params', () async {
    String urlToTest = '/test/some-id?some-other-id=12345&more-ids=963258';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);

    expect(
      response.body,
      'path: {id: some-id}, query: {some-other-id: 12345, more-ids: 963258}',
    );
  });
}
