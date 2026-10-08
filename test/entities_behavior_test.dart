import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The request and response of Winter, without shelf (DECISIONS.md §11)
void main() {
  final Uri uri = Uri.parse('http://localhost/users?page=2');

  group('RequestEntity', () {
    test('headers are case insensitive, with every value in headersAll', () {
      final request = RequestEntity(
        'get',
        uri,
        headers: {
          'X-Tag': ['a', 'b'],
          'Content-Type': 'application/json; charset=iso-8859-1',
        },
      );

      expect(request.method, 'GET');
      expect(request.headers['x-tag'], 'a, b');
      expect(request.headersAll['X-TAG'], ['a', 'b']);
      expect(request.headers.keys, containsAll(['X-Tag', 'Content-Type']));
      expect(request.mimeType, 'application/json');
      expect(request.encoding, latin1);
      expect(() => request.headersAll['x'] = [], throwsUnsupportedError);
    });

    test('a header that is not a String nor a List is an ArgumentError', () {
      expect(
        () => RequestEntity('GET', uri, headers: {'x': 1}),
        throwsArgumentError,
      );
    });

    test('cookies, an invalid one is skipped', () {
      final request = RequestEntity(
        'GET',
        uri,
        headers: {'cookie': 'session=abc; theme=dark; bad cookie=1; noValue'},
      );

      expect(request.cookies.map((cookie) => cookie.name), [
        'session',
        'theme',
      ]);
      expect(request.cookie('theme')?.value, 'dark');
      expect(request.cookie('missing'), isNull);
      expect(RequestEntity('GET', uri).cookies, isEmpty);
    });

    test('the body: a String, bytes or a stream, read once', () async {
      final text = RequestEntity('POST', uri, body: 'año');
      final bytes = RequestEntity('POST', uri, body: [104, 105]);
      final stream = RequestEntity(
        'POST',
        uri,
        body: Stream.value(utf8.encode('streamed')),
      );

      expect(text.contentLength, 4);
      expect(await text.readAsString(), 'año');
      expect(() => text.read(), throwsStateError);
      expect(await bytes.readAsString(), 'hi');
      expect(stream.contentLength, isNull);
      expect(await stream.body<String>(), 'streamed');
      expect(() => RequestEntity('POST', uri, body: 42), throwsArgumentError);
    });

    test('the charset of the Content-Type decodes the body', () async {
      final request = RequestEntity(
        'POST',
        uri,
        headers: {'content-type': 'text/plain; charset="iso-8859-1"'},
        body: latin1.encode('año'),
      );
      final unknown = RequestEntity(
        'POST',
        uri,
        headers: {'content-type': 'text/plain; format=x; charset=unknown'},
        body: 'x',
      );

      expect(await request.body<String>(), 'año');
      expect(unknown.encoding, isNull);
      expect(RequestEntity('GET', uri).encoding, isNull);
      expect(RequestEntity('GET', uri).mimeType, isNull);
    });

    test('a copy shares the body: read once, cached for both', () async {
      final original = RequestEntity('POST', uri, body: '{"a":1}');
      final copy = original.copyWith(headers: {'x': '1'});

      expect(await copy.body<Map<String, dynamic>>(), {'a': 1});
      expect(await original.body<String>(), '{"a":1}');
      expect(original.headers.containsKey('x'), isFalse);
    });

    test('a copy can change the URI, and keeps the connection', () {
      final original = RequestEntity(
        'GET',
        uri,
        connectionInfo: _Connection('10.0.0.1'),
      );
      final copy = original.copyWith(
        requestedUri: uri.replace(query: 'page=3'),
      );

      expect(copy.queryParams, {'page': '3'});
      expect(copy.clientIp(), '10.0.0.1');
      expect(original.queryParams, {'page': '2'});
      expect(() => copy.queryParams['x'] = 'y', throwsUnsupportedError);
      expect(copy.toString(), 'RequestEntity{GET /users}');
    });

    test('the path params are read-only', () {
      final request = RequestEntity('GET', Uri.parse('http://localhost/u/7'))
        ..setRoutingContext(
          RequestRoutingContext(
            path: '/u/{id}',
            key: 'u',
            method: HttpMethod.get,
          ),
        );

      expect(request.pathParams, {'id': '7'});
      expect(() => request.pathParams.clear(), throwsUnsupportedError);
    });
  });

  group('ResponseEntity', () {
    test('cookies are one Set-Cookie each, a copy adds more', () {
      final response = ResponseEntity.ok(
        body: 'x',
        cookies: [Cookie('a', '1')],
      ).copyWith(cookies: [Cookie('b', '2')..httpOnly = false]);

      expect(response.headersAll[HttpHeader.setCookie], [
        'a=1; HttpOnly',
        'b=2',
      ]);
      expect(
        ResponseEntity<void>.created(cookies: [Cookie('c', '3')])
            .headersAll['set-cookie'],
        hasLength(1),
      );
      expect(
        ResponseEntity<void>.accepted(cookies: [Cookie('c', '3')])
            .headersAll['set-cookie'],
        hasLength(1),
      );
      expect(
        ResponseEntity<void>.noContent(cookies: [Cookie('c', '3')])
            .headersAll['set-cookie'],
        hasLength(1),
      );
    });

    test('a header with several values', () {
      final response = ResponseEntity<void>(
        200,
        headers: {
          'Link': ['<a>; rel=next', '<b>; rel=last'],
        },
      );

      expect(response.headersAll['link'], hasLength(2));
      expect(response.headers['link'], '<a>; rel=next, <b>; rel=last');
    });

    test('a Uint8List is sent as bytes, a Stream as a stream', () async {
      final bytes = ResponseEntity<Uint8List>(
        200,
        body: Uint8List.fromList([1, 2, 3]),
      );
      final stream = ResponseEntity<Stream<List<int>>>(
        200,
        body: Stream.fromIterable([
          [1],
          [2],
        ]),
      );

      expect(bytes.headers['content-type'], 'application/octet-stream');
      expect(bytes.contentLength, 3);
      expect(bytes.isStreamed, isFalse);
      expect(stream.contentLength, isNull);
      expect(stream.isStreamed, isTrue);
      expect(await stream.read().expand((chunk) => chunk).toList(), [1, 2]);
      expect(() => stream.read(), throwsStateError);
      expect(ResponseEntity<void>(200).contentLength, 0);
      expect(
        ResponseEntity<void>.tooManyRequests(headers: {'x': '1'}).headers,
        containsPair('x', '1'),
      );
      expect(ResponseEntity<void>(200).toString(), 'ResponseEntity{200}');
    });

    test('a copy without a body shares it, never serialized again', () async {
      final original = ResponseEntity.ok(body: {'a': 1});
      final copy = original.copyWith(headers: {'x': '1'}, context: {'k': 'v'});

      expect(copy.body(), {'a': 1});
      expect(copy.context, {'k': 'v'});
      expect(jsonDecode(await copy.readAsString()), {'a': 1});
      expect(() => original.read(), throwsStateError);
    });
  });
}

class _Connection implements HttpConnectionInfo {
  @override
  final InternetAddress remoteAddress;

  _Connection(String ip) : remoteAddress = InternetAddress(ip);

  @override
  int get localPort => 8080;

  @override
  int get remotePort => 50000;
}
