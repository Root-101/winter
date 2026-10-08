@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/src/winter_server.dart' show limitBodySize;
import 'package:winter/winter.dart';

void main() {
  int port = 9071;
  String localUrl = 'http://localhost:$port';
  const limit = 1024;

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port, maxBodySize: limit),
      router: WinterRouter(
        routes: [
          Route.post(
            path: '/echo',
            handler: (request) async {
              final body = await request.body<String>();
              return ResponseEntity.ok(body: '${body.length}');
            },
          ),
          Route.post(
            path: '/ignore-body',
            handler: (request) => ResponseEntity.ok(body: 'ignored'),
          ),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Body within the limit is read', () async {
    final response = await http.post(url('/echo'), body: 'a' * limit);

    expect(response.statusCode, 200);
    expect(response.body, '$limit');
  });

  test('Body bigger than the limit (Content-Length) returns 413', () async {
    final response = await http.post(url('/echo'), body: 'a' * (limit + 1));

    expect(response.statusCode, 413);
  });

  test(
    'Chunked body (no Content-Length) bigger than the limit returns 413',
    () async {
      final request = http.StreamedRequest('POST', url('/echo'));
      for (int i = 0; i < 4; i++) {
        request.sink.add(utf8.encode('a' * (limit ~/ 2)));
      }
      unawaited(request.sink.close());

      final response = await http.Response.fromStream(await request.send());

      expect(request.contentLength, isNull);
      expect(response.statusCode, 413);
    },
  );

  test('A big body is not a problem if the handler does not read it', () async {
    final response = await http.post(
      url('/ignore-body'),
      body: 'a' * (limit * 4),
    );

    expect(response.statusCode, 200);
    expect(response.body, 'ignored');
  });

  test('Default limit is 10 MB and null means no limit', () {
    expect(const ServerConfig().maxBodySize, 10 * 1024 * 1024);
    expect(const ServerConfig(maxBodySize: null).maxBodySize, isNull);
  });

  test('limitBodySize fails as soon as the limit is exceeded', () async {
    final chunks = Stream.fromIterable([
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9],
    ]);
    final read = <List<int>>[];

    await expectLater(
      limitBodySize(chunks, maxBytes: 5).forEach(read.add),
      throwsA(isA<PayloadTooLargeException>()),
    );
    expect(read, [
      [1, 2, 3],
    ]);
  });
}
