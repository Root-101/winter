@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The server on `dart:io`, without shelf (DECISIONS.md §11)
void main() {
  const int port = 9110;
  final Uri base = Uri.parse('http://localhost:$port');
  late StreamController<List<int>> events;
  late List<String> logs;

  WinterRouter router() => WinterRouter(
    routes: [
      Route.get(
        path: '/cookies',
        handler: (request) => ResponseEntity.ok(
          body: {
            for (final cookie in request.cookies) cookie.name: cookie.value,
          },
          cookies: [
            Cookie('session', 'abc')..httpOnly = true,
            Cookie('theme', 'dark'),
          ],
        ),
      ),
      Route.get(
        path: '/header-names',
        handler: (request) => ResponseEntity.ok(
          body: {
            'names': request.headersAll.keys.toList(),
            'hasHost': request.headersAll.containsKey('HOST'),
            'hasMissing': request.headersAll.containsKey('x-missing'),
          },
        ),
      ),
      Route.get(
        path: '/headers',
        handler: (request) =>
            ResponseEntity.ok(body: request.headersAll['x-multi']),
      ),
      Route.get(
        path: '/text',
        handler: (request) => ResponseEntity.ok(body: 'año'),
      ),
      Route.post(
        path: '/text',
        handler: (request) async =>
            ResponseEntity.ok(body: await request.body<String>()),
      ),
      Route.get(
        path: '/empty',
        handler: (request) => ResponseEntity.noContent(),
      ),
      Route.get(
        path: '/status/{code}',
        handler: (request) =>
            ResponseEntity<void>(request.pathParam<int>('code')),
      ),
      Route.get(
        path: '/broken',
        handler: (request) => ResponseEntity<Stream<List<int>>>(
          200,
          body: (() async* {
            yield utf8.encode('first');
            throw StateError('the stream failed');
          })(),
        ),
      ),
      Route.get(
        path: '/events',
        handler: (request) => ResponseEntity<Stream<List<int>>>(
          200,
          body: events.stream,
          headers: {HttpHeader.contentType: 'text/event-stream'},
        ),
      ),
    ],
  );

  Future<HttpClientResponse> get(String path, {String method = 'GET'}) async {
    final client = HttpClient();
    final request = await client.openUrl(method, base.resolve(path));
    final response = await request.close();
    client.close();
    return response;
  }

  group('A real server', () {
    setUpAll(() async {
      logs = [];
      Winter.context.setUp(logger: _MemoryLogger(logs));
      await Winter.start(
        config: const ServerConfig(port: port, handleSignals: false),
        router: router(),
      );
    });

    tearDownAll(() async {
      await Winter.close(force: true);
      Winter.context.setUp(logger: const ConsoleLogger());
    });

    test('reads the cookies and sets one Set-Cookie per cookie', () async {
      final client = HttpClient();
      final request = await client.getUrl(base.resolve('/cookies'));
      request.headers.set(HttpHeader.cookie, 'a=1; b=2');
      final response = await request.close();
      client.close();

      expect(jsonDecode(await utf8.decodeStream(response)), {
        'a': '1',
        'b': '2',
      });
      // The Cookie of dart:io is HttpOnly by default
      expect(response.headers[HttpHeader.setCookie], [
        'session=abc; HttpOnly',
        'theme=dark; HttpOnly',
      ]);
      expect(response.cookies.map((cookie) => cookie.name), [
        'session',
        'theme',
      ]);
    });

    test('the headers of dart:io are read as a case insensitive map', () async {
      final body = jsonDecode(
        await utf8.decodeStream(await get('/header-names')),
      ) as Map<String, dynamic>;

      expect(body['names'], contains('host'));
      expect(body['hasHost'], isTrue);
      expect(body['hasMissing'], isFalse);
    });

    test('a header sent several times keeps all of its values', () async {
      final socket = await Socket.connect('localhost', port);
      socket.write(
        'GET /headers HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n'
        'X-Multi: one\r\nX-Multi: two\r\n\r\n',
      );
      final answer = await utf8.decodeStream(socket);
      socket.destroy();

      expect(jsonDecode(answer.split('\r\n\r\n').last), ['one', 'two']);
    });

    test(
      'a text body has its length, a Date, and no framework header',
      () async {
        final response = await get('/text');
        final body = await utf8.decodeStream(response);

        expect(body, 'año');
        expect(response.contentLength, utf8.encode('año').length);
        expect(response.headers.date, isNotNull);
        expect(response.headers[HttpHeaders.serverHeader], isNull);
        expect(response.headers['x-powered-by'], isNull);
        expect(response.headers.contentType?.charset, 'utf-8');
      },
    );

    test(
      'the body of a request is read with the charset of its Content-Type',
      () async {
        final client = HttpClient();
        final request = await client.postUrl(base.resolve('/text'));
        request.headers.set(
          HttpHeader.contentType,
          'text/plain; charset=iso-8859-1',
        );
        request.add(latin1.encode('año'));
        final response = await request.close();
        client.close();

        expect(await utf8.decodeStream(response), 'año');
      },
    );

    test('HEAD and 204 have no body; HEAD keeps the length of GET', () async {
      final head = await get('/text', method: 'HEAD');
      final empty = await get('/empty');

      expect(await head.toList(), isEmpty);
      expect(head.contentLength, utf8.encode('año').length);
      expect(empty.statusCode, 204);
      expect(await empty.toList(), isEmpty);
    });

    test('a stream is sent as it is produced (Server-Sent Events)', () async {
      events = StreamController<List<int>>();
      final Future<HttpClientResponse> request = get('/events');
      // dart:io sends the headers with the first chunk
      events.add(utf8.encode('data: 1\n\n'));
      final response = await request;
      final iterator = StreamIterator(response.transform(utf8.decoder));

      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, 'data: 1\n\n');
      expect(response.headers.chunkedTransferEncoding, isTrue);

      events.add(utf8.encode('data: 2\n\n'));
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, 'data: 2\n\n');

      await events.close();
      expect(await iterator.moveNext(), isFalse);
    });

    test(
      'a client that leaves in the middle of a stream never breaks the server',
      () async {
        events = StreamController<List<int>>();
        final socket = await Socket.connect('localhost', port);
        socket.write('GET /events HTTP/1.1\r\nHost: localhost\r\n\r\n');
        events.add(utf8.encode('data: 1\n\n'));
        await socket.first;
        socket.destroy();

        // The server keeps writing to a closed connection until it notices
        for (var i = 0; i < 20 && !events.isPaused; i++) {
          events.add(utf8.encode('data: more\n\n'));
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        unawaited(events.close());

        final response = await get('/text');
        expect(await utf8.decodeStream(response), 'año');
      },
    );

    test('a stream that fails in the middle closes the connection', () async {
      final response = await get('/broken');

      await expectLater(
        response.transform(utf8.decoder).join(),
        throwsA(isA<HttpException>()),
      );
      expect(
        logs,
        contains(startsWith('LogLevel.debug The response of GET could not')),
      );
      expect(await utf8.decodeStream(await get('/text')), 'año');
    });

    test('the status line has the reason phrase of StatusCode', () async {
      Future<String> statusLine(int code) async {
        final socket = await Socket.connect('localhost', port);
        socket.write(
          'GET /status/$code HTTP/1.1\r\nHost: localhost\r\n'
          'Connection: close\r\n\r\n',
        );
        final String answer = await utf8.decodeStream(socket);
        socket.destroy();
        return answer.split('\r\n').first;
      }

      // dart:io alone sends `422 Status 422`
      expect(await statusLine(422), 'HTTP/1.1 422 Unprocessable Entity');
      expect(await statusLine(429), 'HTTP/1.1 429 Too Many Requests');
      expect(await statusLine(418), "HTTP/1.1 418 I'm a teapot");
      // A code with a deprecated twin: the current phrase
      expect(await statusLine(413), 'HTTP/1.1 413 Payload Too Large');
      expect(await statusLine(200), 'HTTP/1.1 200 OK');
      // A code that StatusCode doesn't know keeps the one of dart:io
      expect(await statusLine(799), 'HTTP/1.1 799 Status 799');
    });

    test(
      'a malformed request is answered by dart:io, the server goes on',
      () async {
        final socket = await Socket.connect('localhost', port);
        socket.write('NOT HTTP AT ALL\r\n\r\n');
        final answer = await utf8.decodeStream(socket);
        socket.destroy();

        expect(answer, anyOf(isEmpty, contains('400')));
        expect(await utf8.decodeStream(await get('/text')), 'año');
      },
    );
  });

  group('ServerConfig of dart:io', () {
    tearDown(() => Winter.close(force: true));

    test(
      'autoCompress gzips the responses for a client that accepts it',
      () async {
        await Winter.start(
          config: const ServerConfig(
            port: port + 1,
            handleSignals: false,
            autoCompress: true,
          ),
          router: WinterRouter(
            routes: [
              Route.get(
                path: '/big',
                handler: (request) => ResponseEntity.ok(body: 'winter ' * 500),
              ),
            ],
          ),
        );
        final client = HttpClient()..autoUncompress = false;
        final request = await client.getUrl(
          Uri.parse('http://localhost:${port + 1}/big'),
        );
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
        final response = await request.close();
        final bytes = await response.fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        );
        client.close();

        expect(
          response.headers.value(HttpHeaders.contentEncodingHeader),
          'gzip',
        );
        expect(utf8.decode(gzip.decode(bytes)), 'winter ' * 500);
      },
    );

    test('HTTPS with a securityContext', () async {
      final certificate = File('test/fixtures/localhost_cert.pem')
          .readAsBytesSync();
      await Winter.start(
        config: ServerConfig(
          port: port + 2,
          handleSignals: false,
          securityContext: SecurityContext()
            ..useCertificateChainBytes(certificate)
            ..usePrivateKeyBytes(
              File('test/fixtures/localhost_key.pem').readAsBytesSync(),
            ),
        ),
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/secure',
              handler: (request) =>
                  ResponseEntity.ok(body: request.requestedUri.scheme),
            ),
          ],
        ),
      );
      final client = HttpClient(
        context: SecurityContext()..setTrustedCertificatesBytes(certificate),
      );
      final response = await (await client.getUrl(
        Uri.parse('https://localhost:${port + 2}/secure'),
      )).close();
      client.close();

      expect(await utf8.decodeStream(response), 'https');
    });

    test('a negative idleTimeout is rejected before opening the port', () {
      expect(
        () => Winter.start(
          config: const ServerConfig(
            port: port + 3,
            idleTimeout: Duration(seconds: -1),
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

class _MemoryLogger extends WinterLogger {
  final List<String> logs;

  _MemoryLogger(this.logs);

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => logs.add('$level $message');
}
