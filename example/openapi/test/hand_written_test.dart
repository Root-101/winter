import 'package:openapi_examples/hand_written.dart';
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

  test('the query params', () async {
    expect((await operation('get', '/payments'))['parameters'], [
      {
        'name': 'page',
        'in': 'query',
        'required': false,
        'description': 'From 1',
        'schema': {'type': 'integer', 'minimum': 1},
      },
      {
        'name': 'status',
        'in': 'query',
        'required': false,
        'schema': {
          'type': 'string',
          'enum': ['pending', 'paid', 'refunded'],
        },
      },
    ]);
  });

  test('the schema as written: optional, nullable, a map', () async {
    final post = await operation('post', '/payments');
    final schema =
        (post['requestBody'] as Map)['content']['application/json']['schema']
            as Map;

    expect(schema['required'], ['amount', 'currency']);
    expect(schema['properties']['note'], {
      'type': ['string', 'null'],
      'maxLength': 200,
    });
    expect(schema['properties']['metadata'], {
      'type': 'object',
      'additionalProperties': {'type': 'string'},
    });
    expect(post['responses']['402']['content']['application/json']['schema'], {
      'type': 'object',
      'properties': {
        'missing': {'type': 'number'},
      },
    });
  });
}
