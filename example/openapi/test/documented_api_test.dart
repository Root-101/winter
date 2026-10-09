import 'package:openapi_examples/documented_api.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(
    router: router(),
    globalFilterConfig: globalFilters(),
  );

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  Future<Map<String, dynamic>> document() async =>
      (await client.get('/api/v1/openapi.json')).json as Map<String, dynamic>;

  test('the info, the servers and the groups', () async {
    final doc = await document();

    expect(doc['info'], {
      'title': 'Library',
      'version': '1.0.0',
      'description':
          'The books of the library. The admin routes need `admin-token`.',
    });
    expect(doc['servers'], [
      {'url': 'http://localhost:8080'},
    ]);
    expect(doc['tags'], [
      {'name': 'books'},
      {'name': 'admin'},
    ]);
  });

  test('the paths take the basePath, the children take the tags', () async {
    final paths = (await document())['paths'] as Map;

    expect(paths.keys, [
      '/api/v1/books',
      '/api/v1/books/{id}',
      '/api/v1/admin/books',
      '/api/v1/admin/books/{id}',
    ]);
    expect(paths['/api/v1/books']['get']['tags'], ['books']);
    expect(paths['/api/v1/admin/books']['post']['tags'], ['admin']);
  });

  test('only the admin group is protected', () async {
    final paths = (await document())['paths'] as Map;

    expect(paths['/api/v1/books']['get'], isNot(contains('security')));
    expect(paths['/api/v1/admin/books']['post']['security'], [
      {'bearerAuth': <String>[]},
    ]);
    expect(
      (paths['/api/v1/admin/books/{id}']['delete']['responses'] as Map).keys,
      ['204', '400', '401', '403', '404'],
    );
  });

  test('the API does what the document says', () async {
    final anonymous = await client.post(
      '/api/v1/admin/books',
      body: NewBook.example.toJson(),
    );
    final admin = await client.post(
      '/api/v1/admin/books',
      body: NewBook.example.toJson(),
      headers: {HttpHeader.authorization: 'Bearer admin-token'},
    );

    expect(anonymous.statusCode, 401);
    expect(admin.statusCode, 201);
    expect(
      (await client.get('/api/v1/books?author=Frank%20Herbert')).json,
      hasLength(2),
    );
    expect(
      (await client.get('/api/v1/docs')).body,
      contains('/api/v1/openapi.json'),
    );
  });
}
