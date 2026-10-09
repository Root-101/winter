import 'package:openapi_examples/automatic.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  /// The document, as the client gets it
  Future<Map<String, dynamic>> document() async =>
      (await client.get('/openapi.json')).json as Map<String, dynamic>;

  /// The operation of [method] at [path]
  Future<Map<String, dynamic>> operation(String method, String path) async =>
      ((await document())['paths'] as Map)[path][method]
          as Map<String, dynamic>;

  test('the paths, without the regex of the params', () async {
    expect(((await document())['paths'] as Map).keys, [
      '/products/{id}',
      '/countries/{code}',
      '/search',
      '/health',
    ]);
  });

  test('typed path params, with their 400 and 404', () async {
    final get = await operation('get', '/products/{id}');
    final country = await operation('get', '/countries/{code}');

    expect((get['parameters'] as List).single, {
      'name': 'id',
      'in': 'path',
      'required': true,
      'schema': {'type': 'integer'},
    });
    expect((get['responses'] as Map).keys, ['200', '400', '404']);
    expect(((country['parameters'] as List).single as Map)['schema'], {
      'type': 'string',
      'pattern': '^[A-Z][A-Z]\$',
    });
  });

  test('the security of an AuthFilter, and a rate limit', () async {
    final delete = await operation('delete', '/products/{id}');
    final search = await operation('get', '/search');

    expect(delete['security'], [
      {'bearerAuth': <String>[]},
    ]);
    expect((delete['responses'] as Map).keys, containsAll(['401', '403']));
    expect((search['responses'] as Map).keys, contains('429'));
    expect(((await document())['components'] as Map)['securitySchemes'], {
      'bearerAuth': {'type': 'http', 'scheme': 'bearer'},
    });
  });

  test('Swagger UI points to the document', () async {
    final response = await client.get('/docs');

    expect(response.headers['content-type'], startsWith('text/html'));
    expect(response.body, contains('/openapi.json'));
  });
}
