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
          Route.get(
            path: '/users',
            handler: (request) => ResponseEntity.ok(body: 'users'),
          ),
          Route.get(
            path: '/users/{id}/',
            handler: (request) =>
                ResponseEntity.ok(body: 'user ${request.pathParams['id']}'),
          ),
          Route.get(
            path: '/head-custom',
            handler: (request) => ResponseEntity.ok(body: 'get'),
          ),
          Route(
            path: '/head-custom',
            method: HttpMethod.head,
            handler: (request) =>
                ResponseEntity.ok(headers: {'X-Handled-By': 'head'}),
          ),
          Route.post(
            path: '/only-post',
            handler: (request) => ResponseEntity.ok(body: 'post'),
          ),
          Route.get(
            path: '/file.json',
            handler: (request) => ResponseEntity.ok(body: 'file'),
          ),
          Route.get(
            path: '/files/{name}.txt',
            handler: (request) =>
                ResponseEntity.ok(body: 'txt ${request.pathParams['name']}'),
          ),
          Route.get(
            path: '/regex/.*',
            handler: (request) => ResponseEntity.ok(body: 'regex'),
          ),
        ],
      ),
    );
  });

  group('HEAD', () {
    test('HEAD is handled by the GET route, without body', () async {
      final response = await client.head('/users');

      expect(response.statusCode, 200);
      expect(response.body, isEmpty);
      expect(response.headers['content-length'], '5');
    });

    test('An explicit HEAD route has priority over the GET one', () async {
      final response = await client.head('/head-custom');

      expect(response.statusCode, 200);
      expect(response.headers['x-handled-by'], 'head');
    });

    test('HEAD without a GET route is still a 405', () async {
      final response = await client.head('/only-post');

      expect(response.statusCode, 405);
      expect(response.headers['allow'], 'POST, OPTIONS');
    });

    test('Allow header includes HEAD when GET is allowed', () async {
      final response = await client.delete('/users');

      expect(response.statusCode, 405);
      expect(response.headers['allow'], 'GET, HEAD, OPTIONS');
    });
  });

  group('Trailing slash', () {
    test('A route matches with a trailing slash', () async {
      final response = await client.get('/users/');

      expect(response.statusCode, 200);
      expect(response.body, 'users');
    });

    test('A route declared with trailing slash matches without it', () async {
      final response = await client.get('/users/42');

      expect(response.statusCode, 200);
      expect(response.body, 'user 42');
    });

    test('Path params work with a trailing slash', () async {
      final response = await client.get('/users/42/');

      expect(response.body, 'user 42');
    });
  });

  group('Literal dots', () {
    test('The dot of a static route is literal', () async {
      expect((await client.get('/file.json')).body, 'file');
      expect((await client.get('/fileXjson')).statusCode, 404);
    });

    test('The dot after a path param is literal', () async {
      expect((await client.get('/files/notes.txt')).body, 'txt notes');
      expect((await client.get('/files/notesXtxt')).statusCode, 404);
    });

    test('.* is still a regex', () async {
      expect((await client.get('/regex/a/b/c')).body, 'regex');
    });
  });

  test(
    'Same route declared with and without trailing slash is a duplicate',
    () {
      final duplicated = <Route>[];
      WinterRouter(
        config: RouterConfig(onDuplicatedRoute: duplicated.add),
        routes: [
          Route.get(path: '/a', handler: (r) => ResponseEntity.ok()),
          Route.get(path: '/a/', handler: (r) => ResponseEntity.ok()),
        ],
      );

      expect(duplicated, hasLength(1));
    },
  );
}
