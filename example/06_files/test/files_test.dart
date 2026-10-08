import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:files_example/files_example.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The first bytes of a PNG, and some more
final Uint8List png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ...List<int>.generate(200, (i) => i % 256),
]);

/// `ftyp` at the bytes 4 to 7, as an MP4
final Uint8List mp4 = Uint8List.fromList([
  0,
  0,
  0,
  0x18,
  ...ascii.encode('ftypisom'),
  ...List<int>.generate(300 * 1024, (i) => i % 251),
]);

const String boundary = 'winter-test-boundary';

/// A multipart/form-data body with [fields] and [files] (name: (filename, type, bytes))
Uint8List multipart({
  Map<String, String> fields = const {},
  Map<String, (String, String, List<int>)> files = const {},
}) {
  final BytesBuilder body = BytesBuilder();
  fields.forEach((name, value) {
    body.add(
      utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="$name"\r\n\r\n$value\r\n',
      ),
    );
  });
  files.forEach((name, file) {
    final (String filename, String type, List<int> bytes) = file;
    body
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="$name"; filename="$filename"\r\n'
          'Content-Type: $type\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n'));
  });
  body.add(utf8.encode('--$boundary--\r\n'));
  return body.takeBytes();
}

void main() {
  late Directory uploads;
  late FileStore files;
  late WinterTestClient client;

  setUp(() {
    uploads = Directory.systemTemp.createTempSync('files_example_');
    files = FileStore(uploads);
    final Sessions sessions = Sessions();
    client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([SessionFilter(sessions)]),
      router: FilesApp.router(sessions: sessions, files: files),
    );
  });

  tearDown(() => uploads.deleteSync(recursive: true));

  /// Logs [user] in and returns the `Cookie` header of the session
  Future<String> login([String user = 'ann']) async {
    final TestResponse response = await client.post(
      '/login',
      body: 'user=$user',
      headers: {'content-type': 'application/x-www-form-urlencoded'},
    );
    final Cookie cookie = Cookie.fromSetCookieValue(
      response.headers['set-cookie']!,
    );
    return '${cookie.name}=${cookie.value}';
  }

  Future<TestResponse> upload(String path, Uint8List body, {String? cookie}) =>
      client.post(
        path,
        body: body,
        headers: {
          'content-type': 'multipart/form-data; boundary=$boundary',
          'cookie': ?cookie,
        },
      );

  test('the page with the forms is served at /', () async {
    final TestResponse response = await client.get('/');

    expect(response.statusCode, 200);
    expect(response.headers['content-type'], 'text/html; charset=utf-8');
    expect(response.body, contains('enctype="multipart/form-data"'));
  });

  group('Login with a form and a cookie', () {
    test(
      'sets an HttpOnly, SameSite=Lax session cookie and redirects',
      () async {
        final TestResponse response = await client.post(
          '/login',
          body: 'user=Ann+Lee',
          headers: {'content-type': 'application/x-www-form-urlencoded'},
        );

        expect(response.statusCode, 303);
        expect(response.headers['location'], '/');
        final Cookie cookie = Cookie.fromSetCookieValue(
          response.headers['set-cookie']!,
        );
        expect(cookie.name, sessionCookie);
        expect(cookie.httpOnly, isTrue);
        expect(cookie.sameSite, SameSite.lax);
        expect(cookie.value, matches(RegExp(r'^[0-9a-f]{32}$')));
      },
    );

    test('a form without a user is a 400', () async {
      final TestResponse response = await client.post(
        '/login',
        body: 'user=+',
        headers: {'content-type': 'application/x-www-form-urlencoded'},
      );

      expect(response.statusCode, 400);
    });

    test('without the cookie, or after logging out, it is a 401', () async {
      final String cookie = await login();
      expect((await client.get('/photos')).statusCode, 401);
      expect(
        (await client.get('/photos', headers: {'cookie': cookie})).statusCode,
        200,
      );

      final TestResponse logout = await client.post(
        '/logout',
        headers: {'cookie': cookie},
      );
      final TestResponse after = await client.get(
        '/photos',
        headers: {'cookie': cookie},
      );

      expect(logout.headers['set-cookie'], contains('Max-Age=0'));
      expect(after.statusCode, 401);
      expect(after.headers['www-authenticate'], 'Cookie name="session"');
    });
  });

  group('Photos: formData() of a multipart form', () {
    test('a photo is saved with a name of the app and served back', () async {
      final String cookie = await login();

      final TestResponse response = await upload(
        '/photos',
        multipart(
          fields: {'title': 'Beach'},
          files: {'photo': ('../../evil.png', 'image/png', png)},
        ),
        cookie: cookie,
      );

      expect(response.statusCode, 303);
      final String location = response.headers['location']!;
      expect(location, matches(RegExp(r'^/photos/[0-9a-f]{32}\.png$')));
      expect(
        files.photos.listSync().map((file) => file.uri.pathSegments.last),
        [location.split('/').last],
      );

      final TestResponse photo = await client.get(
        location,
        headers: {'cookie': cookie},
      );
      expect(photo.statusCode, 200);
      expect(photo.headers['content-type'], 'image/png');
      expect(photo.headers['etag'], isNotNull);
      expect(photo.bodyBytes, png);

      final TestResponse list = await client.get(
        '/photos',
        headers: {'cookie': cookie},
      );
      expect(list.json, [
        {
          'id': location.split('/').last,
          'title': 'Beach',
          'owner': 'ann',
          'url': location,
        },
      ]);
    });

    test(
      'the type comes from the bytes, not from what the client says',
      () async {
        final TestResponse response = await upload(
          '/photos',
          multipart(
            fields: {'title': 'Not a photo'},
            files: {
              'photo': ('photo.png', 'image/png', utf8.encode('<script>')),
            },
          ),
          cookie: await login(),
        );

        expect(response.statusCode, 415);
        expect(files.photos.listSync(), isEmpty);
      },
    );

    test('a form without a title or a photo is a 400', () async {
      final TestResponse response = await upload(
        '/photos',
        multipart(fields: {'title': 'Beach'}),
        cookie: await login(),
      );

      expect(response.statusCode, 400);
    });

    test('a path in the id is a 404', () async {
      final TestResponse response = await client.get(
        '/photos/..%2F..%2Fsecret.txt',
        headers: {'cookie': await login()},
      );

      expect(response.statusCode, 404);
    });
  });

  group('Server-Sent Events: GET /photos/events', () {
    test('a new photo is sent as an event, as it is saved', () async {
      final String cookie = await login();
      final ResponseEntity events = await client.handler(
        RequestEntity(
          'GET',
          Uri.parse('http://localhost/photos/events'),
          headers: {'cookie': cookie},
        ),
      );
      final List<String> received = [];
      final subscription = events.read().map(utf8.decode).listen(received.add);
      addTearDown(subscription.cancel);

      final TestResponse uploaded = await upload(
        '/photos',
        multipart(
          fields: {'title': 'Live'},
          files: {'photo': ('live.png', 'image/png', png)},
        ),
        cookie: cookie,
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.headers['content-type'], startsWith('text/event-stream'));
      final String id = uploaded.headers['location']!.split('/').last;
      expect(received, [
        ':\n\n',
        'event: photo\nid: $id\n'
            'data: {"id":"$id","title":"Live","owner":"ann","url":"/photos/$id"}\n\n',
      ]);
    });

    test('without the session cookie it is a 401', () async {
      expect((await client.get('/photos/events')).statusCode, 401);
    });
  });

  group('Videos: multipart() streamed to disk', () {
    test('a video is copied while it arrives, and served with Range', () async {
      final String cookie = await login();

      final TestResponse response = await upload(
        '/videos',
        multipart(
          fields: {'note': 'ignored'},
          files: {'video': ('clip.mp4', 'video/mp4', mp4)},
        ),
        cookie: cookie,
      );

      expect(response.statusCode, 201);
      final Map<String, Object?> saved =
          (response.json as List).single as Map<String, Object?>;
      expect(saved['size'], mp4.length);
      expect(response.headers['location'], saved['url']);

      final TestResponse range = await client.get(
        saved['url']! as String,
        headers: {'cookie': cookie, 'range': 'bytes=4-11'},
      );
      expect(range.statusCode, 206);
      expect(range.headers['content-range'], 'bytes 4-11/${mp4.length}');
      expect(ascii.decode(range.bodyBytes), 'ftypisom');
    });

    test(
      'a file that is not an MP4 is a 415, and nothing is left on disk',
      () async {
        final TestResponse response = await upload(
          '/videos',
          multipart(files: {'video': ('clip.mp4', 'video/mp4', png)}),
          cookie: await login(),
        );

        expect(response.statusCode, 415);
        expect(files.videos.listSync(), isEmpty);
      },
    );

    test('a form without a video is a 400', () async {
      final TestResponse response = await upload(
        '/videos',
        multipart(fields: {'note': 'no file'}),
        cookie: await login(),
      );

      expect(response.statusCode, 400);
    });
  });
}
