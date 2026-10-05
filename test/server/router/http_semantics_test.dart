@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9072;
  String localUrl = 'http://localhost:$port';

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port),
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

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  group('HEAD', () {
    test('HEAD is handled by the GET route, without body', () async {
      final response = await http.head(url('/users'));

      expect(response.statusCode, 200);
      expect(response.body, isEmpty);
      expect(response.headers['content-length'], '5');
    });

    test('An explicit HEAD route has priority over the GET one', () async {
      final response = await http.head(url('/head-custom'));

      expect(response.statusCode, 200);
      expect(response.headers['x-handled-by'], 'head');
    });

    test('HEAD without a GET route is still a 405', () async {
      final response = await http.head(url('/only-post'));

      expect(response.statusCode, 405);
      expect(response.headers['allow'], 'POST');
    });

    test('Allow header includes HEAD when GET is allowed', () async {
      final response = await http.delete(url('/users'));

      expect(response.statusCode, 405);
      expect(response.headers['allow'], 'GET, HEAD');
    });
  });

  group('Trailing slash', () {
    test('A route matches with a trailing slash', () async {
      final response = await http.get(url('/users/'));

      expect(response.statusCode, 200);
      expect(response.body, 'users');
    });

    test('A route declared with trailing slash matches without it', () async {
      final response = await http.get(url('/users/42'));

      expect(response.statusCode, 200);
      expect(response.body, 'user 42');
    });

    test('Path params work with a trailing slash', () async {
      final response = await http.get(url('/users/42/'));

      expect(response.body, 'user 42');
    });
  });

  group('Literal dots', () {
    test('The dot of a static route is literal', () async {
      expect((await http.get(url('/file.json'))).body, 'file');
      expect((await http.get(url('/fileXjson'))).statusCode, 404);
    });

    test('The dot after a path param is literal', () async {
      expect((await http.get(url('/files/notes.txt'))).body, 'txt notes');
      expect((await http.get(url('/files/notesXtxt'))).statusCode, 404);
    });

    test('.* is still a regex', () async {
      expect((await http.get(url('/regex/a/b/c'))).body, 'regex');
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
