@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(() async {
    client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route(
            path: '/get-method',
            method: HttpMethod.get,
            handler: (request) =>
                ResponseEntity.ok(body: 'Response from get-method'),
          ),
          Route(
            path: '/post-method',
            method: HttpMethod.post,
            handler: (request) =>
                ResponseEntity.ok(body: 'Response from post-method'),
          ),
          Route(
            path: '/put-method',
            method: HttpMethod.put,
            handler: (request) =>
                ResponseEntity.ok(body: 'Response from put-method'),
          ),
          Route(
            path: '/delete-method',
            method: HttpMethod.delete,
            handler: (request) =>
                ResponseEntity.ok(body: 'Response from delete-method'),
          ),
          Route(
            path: '/patch-method',
            method: HttpMethod.patch,
            handler: (request) =>
                ResponseEntity.ok(body: 'Response from patch-method'),
          ),
          Route(
            path: '/query-method',
            method: HttpMethod.query,
            handler: (request) =>
                ResponseEntity.ok(body: 'Response from query-method'),
          ),
          Route(
            path: '/custom-method',
            method: const HttpMethod('custom'),
            handler: (request) =>
                ResponseEntity.ok(body: 'Response from custom-method'),
          ),
        ],
      ),
    );
  });

  test('Get-Method', () async {
    String urlToTest = '/get-method';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from get-method');
  });

  test('Post-Method', () async {
    String urlToTest = '/post-method';
    TestResponse response = await client.post(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from post-method');
  });

  test('Put-Method', () async {
    String urlToTest = '/put-method';
    TestResponse response = await client.put(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from put-method');
  });

  test('Delete-Method', () async {
    String urlToTest = '/delete-method';
    TestResponse response = await client.delete(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from delete-method');
  });

  test('Patch-Method', () async {
    String urlToTest = '/patch-method';
    TestResponse response = await client.patch(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, 'Response from patch-method');
  });

  test('405: Method not allowed', () async {
    String urlToTest = '/get-method';
    TestResponse response = await client.post(urlToTest);

    expect(response.statusCode, 405);
    expect((jsonDecode(response.body) as Map)['title'], 'Method Not Allowed');
  });

  test('404: Not found', () async {
    String urlToTest = '/some-other-method';
    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 404);
    expect((jsonDecode(response.body) as Map)['title'], 'Not Found');
  });
}
