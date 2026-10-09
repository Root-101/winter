import 'package:openapi_examples/from_examples.dart';
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

  test(
    'the request: its schema from the example, its constraints from validate()',
    () async {
      final post = await operation('post', '/products');
      final content =
          (post['requestBody'] as Map)['content']['application/json'] as Map;

      expect(content['schema'], {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'minLength': 1, 'maxLength': 80},
          'supportEmail': {'type': 'string', 'format': 'email'},
          'price': {'type': 'number', 'exclusiveMinimum': 0},
          'category': {
            'type': 'string',
            'enum': ['home', 'garden', 'office'],
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'maxItems': 5,
          },
        },
        'required': ['name', 'price', 'category'],
      });
      expect(content['example'], CreateProduct.example.toJson());
    },
  );

  test('the responses: 201 with its example, the 409, and the 422', () async {
    final responses =
        (await operation('post', '/products'))['responses'] as Map;

    expect(responses.keys, containsAll(['201', '409', '400', '415', '422']));
    expect(responses['409'], {
      'description': 'A product with that name already exists',
    });
    expect(responses['201']['content']['application/json']['schema'], {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer'},
        'name': {'type': 'string'},
        'price': {'type': 'number'},
        'createdAt': {'type': 'string', 'format': 'date-time'},
      },
    });
  });

  test('a list response is an array', () async {
    final get = await operation('get', '/products');

    expect(
      get['responses']['200']['content']['application/json']['schema']['type'],
      'array',
    );
  });

  test('the API does what the document says', () async {
    final invalid = await client.post(
      '/products',
      body: {'name': 'Lamp', 'price': 0, 'category': 'kitchen'},
    );
    final created = await client.post(
      '/products',
      body: CreateProduct.example.toJson(),
    );

    expect(invalid.statusCode, 422);
    expect(created.statusCode, 201);
  });
}
