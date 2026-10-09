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
            path: '/test_.*',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(body: 'test'),
          ),
          Route(
            path: '/hi_.*/{id}',
            method: HttpMethod.get,
            handler: (request) =>
                ResponseEntity.ok(body: request.pathParams['id']),
          ),
          Route(
            path: '/anything.*',
            method: HttpMethod.get,
            handler: (request) =>
                ResponseEntity.ok(body: request.requestedUri.path.substring(1)),
          ),
          Route(
            path: '/param-regex/{key|.*}',
            method: HttpMethod.get,
            handler: (request) =>
                ResponseEntity.ok(body: request.pathParams['key']!),
          ),
          Route(
            path: '/param-multi-regex.*/{key|.*}',
            method: HttpMethod.get,
            handler: (request) =>
                ResponseEntity.ok(body: request.pathParams['key']!),
          ),
        ],
      ),
    );
  });

  test('Test /test_(any) #1', () async {
    String urlToTest = '/test_1';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);

    expect(response.body, 'test');
  });

  test('Test /test_(any) #2', () async {
    String urlToTest = '/test_abcdef';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);

    expect(response.body, 'test');
  });

  test('Test /hi_(any)/{id} #1', () async {
    String urlToTest = '/hi_abcdef/123';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);

    expect(response.body, '123');
  });

  test('Test /hi_(any)/{id} #2', () async {
    String urlToTest = '/hi_123456/abc';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);

    expect(response.body, 'abc');
  });

  test('Test /hi_(any)/{id} #3', () async {
    String urlToTest = '/hi_abcdef';

    ///without the /{id} param
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 404);
  });

  test('Test /anything.* #1', () async {
    String urlToTest = '/anything';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'anything');
  });

  test('Test /anything.* #2', () async {
    String urlToTest = '/anything/test';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'anything/test');
  });

  test('Test some other url', () async {
    String urlToTest = '/hello/my/friend';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 404);
  });

  test('Test param regex url', () async {
    String urlToTest = '/param-regex/test/123/test.jpg';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'test/123/test.jpg');
  });

  test('Test param multi regex url', () async {
    String urlToTest1 = '/param-multi-regex/multi/test.jpg';
    TestResponse response1 = await client.get(urlToTest1);

    expect(response1.statusCode, 200);
    expect(response1.body, 'multi/test.jpg');

    String urlToTest2 = '/param-multi-regex-2/multi-2/test-2.jpg';
    TestResponse response2 = await client.get(urlToTest2);
    expect(response2.statusCode, 200);
    expect(response2.body, 'multi-2/test-2.jpg');
  });
}
