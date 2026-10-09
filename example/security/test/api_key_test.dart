import 'package:security_examples/api_key.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(
    globalFilterConfig: globalFilters(exampleKeys),
    router: router(),
  );

  test('a public route needs no key', () async {
    expect((await client.get('/public/status')).statusCode, 200);
  });

  test('no key, or a wrong one: 401 with the challenge', () async {
    for (final headers in [
      <String, String>{},
      {'x-api-key': 'stolen'},
    ]) {
      final response = await client.get('/orders', headers: headers);

      expect(response.statusCode, 401);
      expect(response.headers['www-authenticate'], 'ApiKey header="X-API-Key"');
    }
  });

  test('a key with the permission reaches the handler', () async {
    final response = await client.get(
      '/orders',
      headers: {'x-api-key': 'read-key'},
    );

    expect(response.statusCode, 200);
    expect((response.json as Map)['client'], 'reporting');
  });

  test('a key without the permission is a 403', () async {
    final denied = await client.post(
      '/orders',
      headers: {'x-api-key': 'read-key'},
    );
    final allowed = await client.post(
      '/orders',
      headers: {'x-api-key': 'write-key'},
    );

    expect(denied.statusCode, 403);
    expect(allowed.statusCode, 201);
  });
}
