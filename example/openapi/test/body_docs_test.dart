import 'package:openapi_examples/body_docs.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  /// The document, as the client gets it
  Future<Map<String, dynamic>> document() async =>
      (await client.get('/openapi.json')).json as Map<String, dynamic>;

  /// The operation of [method] at [path]
  Future<Map<String, dynamic>> operation(String method, String path) async =>
      ((await document())['paths'] as Map)[path][method]
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> requestBody(String method, String path) async =>
      (await operation(method, path))['requestBody'] as Map<String, dynamic>;

  test(
    'a schema and an example: the schema wins, the example is shown',
    () async {
      final body = await requestBody('patch', '/me');

      expect(
        body['description'],
        'Only the fields sent change; null clears the nickname',
      );
      expect(body['content']['application/json'], {
        'schema': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'minLength': 1},
            'nickname': {
              'type': ['string', 'null'],
            },
          },
        },
        'example': {'nickname': null},
      });
    },
  );

  test('a JSON example with the rules of a model', () async {
    final put = await operation('put', '/me/password');
    final schema =
        (put['requestBody'] as Map)['content']['application/json']['schema']
            as Map;

    expect(schema['required'], ['current', 'next']);
    expect(schema['properties']['next'], {'type': 'string', 'minLength': 12});
    expect((put['responses'] as Map).keys, containsAll(['204', '422']));
  });

  test('another content type, and a hidden route', () async {
    final body = await requestBody('put', '/me/avatar');

    expect(body['content'], {
      'image/png': {
        'schema': {'type': 'string', 'format': 'binary'},
      },
    });
    expect(
      ((await document())['paths'] as Map).keys,
      isNot(contains('/internal/metrics')),
    );
  });
}
