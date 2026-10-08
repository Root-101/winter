import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late Directory temp;
  late Directory public;
  late WinterTestClient client;

  void write(String path, String content) {
    File('${public.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  setUpAll(() {
    temp = Directory.systemTemp.createTempSync('winter_static_');
    public = Directory('${temp.path}/public')..createSync();
    File('${temp.path}/secret.txt').writeAsStringSync('SECRET');
    write('index.html', '<h1>Home</h1>');
    write('hello.txt', 'Hello, world!');
    write('my file.txt', 'spaces');
    write('css/site.css', 'body{}');
    write('docs/index.html', '<h1>Docs</h1>');
    write('empty/.keep', '');
    write('.env', 'TOKEN=1');
    write('.git/config', 'x');
    write('data.unknownext', 'bin');
    write('notes.md', '# Notes');
    write('zero.txt', '');
    write('app.js', 'run()');
    write('data.json', '{}');
    write('logo.svg', '<svg/>');
    write('photo.PNG', 'png');

    client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/assets/api',
            handler: (r) => ResponseEntity.ok(body: 'api'),
          ),
          Route.static(path: '/assets', directory: public.path),
          Route.static(
            path: '/raw',
            directory: public.path,
            index: null,
            cacheControl: 'public, max-age=60',
            mimeTypes: {'md': 'text/x-markdown'},
          ),
          Route.get(
            path: '/download/{name}',
            handler: (request) =>
                StaticFiles(public.path)
                    .serve(request, request.pathParam<String>('name')),
          ),
        ],
      ),
    );
  });

  tearDownAll(() => temp.deleteSync(recursive: true));

  group('Route.static', () {
    test('serves a file with its type, length and validators', () async {
      final TestResponse response = await client.get('/assets/hello.txt');

      expect(response.statusCode, 200);
      expect(response.body, 'Hello, world!');
      expect(response.headers['content-type'], 'text/plain; charset=utf-8');
      expect(response.headers['content-length'], '13');
      expect(response.headers['accept-ranges'], 'bytes');
      expect(
        response.headers['etag'],
        matches(RegExp(r'^"[0-9a-f]+-[0-9a-f]+"$')),
      );
      expect(
        HttpDate.parse(response.headers['last-modified']!),
        isA<DateTime>(),
      );
      expect(response.headers, isNot(contains('cache-control')));
    });

    test('serves nested and URL-encoded paths', () async {
      expect((await client.get('/assets/css/site.css')).body, 'body{}');
      expect(
        (await client.get('/assets/css/site.css')).headers['content-type'],
        'text/css; charset=utf-8',
      );
      expect((await client.get('/assets/my%20file.txt')).body, 'spaces');
    });

    test(
      'a folder serves its index, after a redirect that adds the /',
      () async {
        final TestResponse root = await client.get('/assets');
        final TestResponse docs = await client.get('/assets/docs?v=2');

        expect(root.statusCode, 308);
        expect(root.headers['location'], 'assets/');
        expect(docs.statusCode, 308);
        expect(docs.headers['location'], 'docs/?v=2');
        expect((await client.get('/assets/')).body, '<h1>Home</h1>');
        expect((await client.get('/assets/docs/')).body, '<h1>Docs</h1>');
        expect(
          (await client.get('/assets/docs/')).headers['content-type'],
          'text/html; charset=utf-8',
        );
      },
    );

    test('a folder without an index, or with index: null, is a 404', () async {
      expect((await client.get('/assets/empty/')).statusCode, 404);
      expect((await client.get('/raw/docs/')).statusCode, 404);
      expect((await client.get('/raw')).statusCode, 404);
    });

    test('a missing file is a 404 Problem Details', () async {
      final TestResponse response = await client.get('/assets/nope.txt');

      expect(response.statusCode, 404);
      expect(
        response.headers['content-type'],
        startsWith('application/problem+json'),
      );
    });

    test(
      'never serves a file out of the directory, nor a hidden one',
      () async {
        for (final String path in [
          '/assets/%2e%2e/secret.txt',
          '/assets/%2E%2E%2Fsecret.txt',
          '/assets/css/%2e%2e/%2e%2e/secret.txt',
          '/assets/..%5Csecret.txt',
          '/assets/%5C..%5Csecret.txt',
          '/assets/.env',
          '/assets/.git/config',
          '/assets/hello.txt%3A%3A%24DATA',
          '/assets/hello.txt%00.png',
        ]) {
          final TestResponse response = await client.get(path);

          expect(response.statusCode, 404, reason: path);
          expect(response.body, isNot(contains('SECRET')), reason: path);
          expect(response.body, isNot(contains('TOKEN')), reason: path);
        }
      },
    );

    test('a link that leads out of the directory is a 404', () async {
      final Link link = Link('${public.path}/escape.txt');
      try {
        link.createSync('${temp.path}/secret.txt');
      } on FileSystemException {
        markTestSkipped('This system does not allow creating links');
        return;
      }
      addTearDown(link.deleteSync);

      final TestResponse response = await client.get('/assets/escape.txt');

      expect(response.statusCode, 404);
      expect(response.body, isNot(contains('SECRET')));
    });

    test('HEAD has the headers and no body; POST is a 405', () async {
      final TestResponse head = await client.head('/assets/hello.txt');
      final TestResponse post = await client.post('/assets/hello.txt');

      expect(head.statusCode, 200);
      expect(head.headers['content-length'], '13');
      expect(head.body, isEmpty);
      expect(post.statusCode, 405);
      expect(post.headers['allow'], contains('GET'));
    });

    test('a route declared before it wins', () async {
      expect((await client.get('/assets/api')).body, 'api');
    });

    test('cacheControl, mimeTypes and an unknown extension', () async {
      final TestResponse md = await client.get('/raw/notes.md');
      final TestResponse defaultMd = await client.get('/assets/notes.md');
      final TestResponse unknown = await client.get('/assets/data.unknownext');

      expect(md.headers['cache-control'], 'public, max-age=60');
      expect(md.headers['content-type'], 'text/x-markdown; charset=utf-8');
      expect(defaultMd.headers['content-type'], 'text/markdown; charset=utf-8');
      expect(unknown.headers['content-type'], 'application/octet-stream');
      for (final (String file, String type) in [
        ('app.js', 'application/javascript; charset=utf-8'),
        ('data.json', 'application/json; charset=utf-8'),
        ('logo.svg', 'image/svg+xml; charset=utf-8'),
        ('photo.PNG', 'image/png'),
      ]) {
        expect(
          (await client.get('/assets/$file')).headers['content-type'],
          type,
          reason: file,
        );
      }
    });

    test('at the root of the server', () async {
      final WinterTestClient root = WinterTestClient.build(
        router: WinterRouter(
          routes: [Route.static(path: '/', directory: public.path)],
        ),
      );

      expect((await root.get('/')).body, '<h1>Home</h1>');
      expect((await root.get('/css/site.css')).body, 'body{}');
      expect((await root.get('/docs')).headers['location'], 'docs/');
      expect((await root.get('/%2e%2e/secret.txt')).statusCode, 404);
    });

    test('a directory that does not exist is an ArgumentError', () {
      expect(
        () => Route.static(path: '/x', directory: '${temp.path}/missing'),
        throwsArgumentError,
      );
    });

    test('StaticFiles.serve works from any handler', () async {
      expect((await client.get('/download/hello.txt')).body, 'Hello, world!');
      expect((await client.get('/download/.env')).statusCode, 404);
      expect(StaticFiles(public.path).toString(), startsWith('StaticFiles{'));
    });
  });

  group('Conditional requests', () {
    late String etag;
    late String lastModified;

    setUpAll(() async {
      final TestResponse response = await client.get('/assets/hello.txt');
      etag = response.headers['etag']!;
      lastModified = response.headers['last-modified']!;
    });

    Future<TestResponse> get(Map<String, Object> headers, [String? path]) =>
        client.get(path ?? '/raw/hello.txt', headers: headers);

    test('If-None-Match with the ETag is a 304 without a body', () async {
      for (final String value in [etag, 'W/$etag', '"other", $etag', '*']) {
        final TestResponse response = await get({'If-None-Match': value});

        expect(response.statusCode, 304, reason: value);
        expect(response.body, isEmpty);
        expect(response.headers['etag'], etag);
        expect(response.headers['cache-control'], 'public, max-age=60');
      }
      expect((await get({'If-None-Match': '"other"'})).statusCode, 200);
    });

    test('If-Modified-Since', () async {
      final String future = HttpDate.format(
        DateTime.now().add(const Duration(days: 1)),
      );
      final String past = HttpDate.format(DateTime.utc(2000));

      expect((await get({'If-Modified-Since': lastModified})).statusCode, 304);
      expect((await get({'If-Modified-Since': future})).statusCode, 304);
      expect((await get({'If-Modified-Since': past})).statusCode, 200);
      expect((await get({'If-Modified-Since': 'not a date'})).statusCode, 200);
    });

    test('If-None-Match wins over If-Modified-Since', () async {
      final TestResponse response = await get({
        'If-None-Match': '"other"',
        'If-Modified-Since': lastModified,
      });

      expect(response.statusCode, 200);
    });
  });

  group('Range requests', () {
    Future<TestResponse> range(String value, [Map<String, Object>? extra]) =>
        client.get('/assets/hello.txt', headers: {'Range': value, ...?extra});

    test('a range of bytes is a 206 with its Content-Range', () async {
      final Map<String, (String, String)> cases = {
        'bytes=0-4': ('Hello', 'bytes 0-4/13'),
        'bytes=7-': ('world!', 'bytes 7-12/13'),
        'bytes=-6': ('world!', 'bytes 7-12/13'),
        'bytes=-100': ('Hello, world!', 'bytes 0-12/13'),
        'bytes=7-1000': ('world!', 'bytes 7-12/13'),
        ' bytes=12-12 ': ('!', 'bytes 12-12/13'),
      };
      for (final MapEntry<String, (String, String)> entry in cases.entries) {
        final TestResponse response = await range(entry.key);

        expect(response.statusCode, 206, reason: entry.key);
        expect(response.body, entry.value.$1, reason: entry.key);
        expect(response.headers['content-range'], entry.value.$2);
        expect(
          response.headers['content-length'],
          '${utf8.encode(entry.value.$1).length}',
        );
      }
    });

    test('a range out of the file is a 416 with the size', () async {
      for (final String value in ['bytes=13-', 'bytes=100-200', 'bytes=-0']) {
        final TestResponse response = await range(value);

        expect(response.statusCode, 416, reason: value);
        expect(response.headers['content-range'], 'bytes */13');
      }
      final TestResponse empty = await client.get(
        '/assets/zero.txt',
        headers: {'Range': 'bytes=0-'},
      );
      expect(empty.statusCode, 416);
      expect(empty.headers['content-range'], 'bytes */0');
    });

    test('an invalid range, or several, sends the whole file', () async {
      for (final String value in [
        'bytes=5-2',
        'bytes=0-1,3-4',
        'items=0-1',
        'bytes=-',
        'bytes=a-b',
        'bytes=${'9' * 30}-',
        'bytes=-${'9' * 30}',
      ]) {
        final TestResponse response = await range(value);

        expect(response.statusCode, 200, reason: value);
        expect(response.body, 'Hello, world!', reason: value);
      }
    });

    test('If-Range: the range only while the file is the same', () async {
      final TestResponse first = await client.get('/assets/hello.txt');
      final String etag = first.headers['etag']!;
      final String lastModified = first.headers['last-modified']!;

      expect((await range('bytes=0-4', {'If-Range': etag})).statusCode, 206);
      expect(
        (await range('bytes=0-4', {'If-Range': lastModified})).statusCode,
        206,
      );
      for (final String stale in [
        '"other"',
        'W/$etag',
        HttpDate.format(DateTime.utc(2000)),
        'not a date',
      ]) {
        final TestResponse response = await range('bytes=0-4', {
          'If-Range': stale,
        });

        expect(response.statusCode, 200, reason: stale);
        expect(response.body, 'Hello, world!');
      }
    });
  });
}
