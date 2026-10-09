import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:winter/src/request_entity.dart' show attachRoute;
import 'package:winter/winter.dart';

void main() {
  group('RequestEntity copyWith', () {
    test('should return an object with identical fields when no parameters are provided', () async {
      final uri = Uri.parse('http://localhost/test?q=1');
      final original = RequestEntity(
        'POST',
        uri,
        headers: {'content-type': 'text/plain', 'x-custom': 'value'},
        body: 'hello world',
      )..context.set(_auth, 'token123');

      // Ensure body is read and cached
      await original.body<String>();

      final copy = original.copyWith();

      // Check basic Request fields
      expect(copy.method, equals(original.method));
      expect(copy.requestedUri, equals(original.requestedUri));
      expect(copy.headers, equals(original.headers));
      expect(copy.protocolVersion, equals(original.protocolVersion));
      expect(copy.encoding, equals(original.encoding));

      // The context starts with the same values, in a map of its own
      expect(copy.context.get(_auth), 'token123');
      expect(copy.context, isNot(same(original.context)));
      copy.context.set(_auth, 'changed');
      expect(original.context.get(_auth), 'token123');

      // Check body
      expect(await copy.body<String>(), equals(await original.body<String>()));

      // Check derived fields
      expect(copy.queryParams, equals(original.queryParams));
      expect(copy.pathParams, equals(original.pathParams));
      expect(copy.httpMethod.name, equals(original.httpMethod.name));
    });

    test('keeps the route (and its path params) and the security context', () {
      final original = RequestEntity(
        'GET',
        Uri.parse('http://localhost/users/123'),
      );

      attachRoute(
        original,
        Route.get(
          path: '/users/{id}',
          key: 'user_detail',
          handler: (r) => ResponseEntity.ok(),
        ),
      );
      original.securityContext.setAuthentication(
        Authentication(principal: 'adam'),
      );
      expect(original.pathParams, equals({'id': '123'}));

      final copy = original.copyWith(headers: {'x-new': '1'});

      expect(copy.route, isNotNull);
      expect(copy.route!.key, equals('user_detail'));
      expect(copy.pathParams, equals({'id': '123'}));
      expect(copy.securityContext, same(original.securityContext));
    });

    test('adds headers, null removes a header', () async {
      final original = RequestEntity(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'a': 'b', 'remove-me': 'x'},
      );

      final copy = original.copyWith(
        headers: {'c': 'd', 'REMOVE-ME': null},
        body: 'new body',
      );

      expect(copy.headers, containsPair('c', 'd'));
      expect(copy.headers, containsPair('a', 'b'));
      expect(copy.headers.containsKey('remove-me'), isFalse);
      expect(await copy.body<String>(), equals('new body'));
    });
  });

  group('RequestEntity body', () {
    RequestEntity jsonRequest() => RequestEntity(
      'POST',
      Uri.parse('http://localhost/'),
      body: '{"name":"Adam","age":30}',
    );

    test('can be read multiple times with different types', () async {
      final request = jsonRequest();

      final map = await request.body<Map<String, dynamic>>();
      final raw = await request.body<String>();
      final mapAgain = await request.body<Map<String, dynamic>>();

      expect(map, {'name': 'Adam', 'age': 30});
      expect(raw, '{"name":"Adam","age":30}');
      expect(mapAgain, map);
    });

    test('concurrent calls share the same read of the stream', () async {
      final request = jsonRequest();

      final results = await Future.wait([
        request.body<String>(),
        request.body<String>(),
      ]);

      expect(results[0], results[1]);
    });

    test('copyWith after a typed body keeps the raw body', () async {
      final request = jsonRequest();
      await request.body<Map<String, dynamic>>();

      final copy = request.copyWith(headers: {'x': '1'});

      expect(await copy.body<String>(), '{"name":"Adam","age":30}');
      expect(await copy.body<Map<String, dynamic>>(), {
        'name': 'Adam',
        'age': 30,
      });
    });
  });

  group('ResponseEntity copyWith', () {
    test('should return an object with identical fields when no parameters are provided', () {
      final original = ResponseEntity<Map>(
        200,
        body: {'id': 1},
        headers: {'content-type': 'application/json'},
      )..context.set(_cache, true);

      final copy = original.copyWith();

      expect(copy, isA<ResponseEntity<Map>>());
      expect(copy.statusCode, equals(original.statusCode));
      expect(copy.headers, equals(original.headers));
      expect(copy.context.get(_cache), isTrue);
      expect(copy.encoding, equals(original.encoding));
      expect(copy.body(), equals(original.body()));

      // Verification of deep equality for body if it's a map
      expect(copy.body(), isA<Map>());
      expect(copy.body()['id'], equals(1));
    });

    test('should allow overriding fields', () {
      final original = ResponseEntity.ok(body: 'old');

      final copy = original.copyWith(
        statusCode: 201,
        body: 'new',
        headers: {'x-res': 'val'},
      );

      expect(copy.statusCode, equals(201));
      expect(copy.body(), equals('new'));
      expect(copy.headers['x-res'], equals('val'));
    });

    test(
      'keeps a body of bytes (a Uint8List is never serialized as JSON)',
      () async {
        final bytes = ResponseEntity<Object>(
          200,
          body: 'old',
        ).copyWith(body: Uint8List.fromList([104, 105]));

        expect(await bytes.copyWith(statusCode: 201).readAsString(), 'hi');
      },
    );

    test('does not serialize the body again', () async {
      final counter = _CountingBody();
      final copy = ResponseEntity.ok(body: counter).copyWith(statusCode: 201);

      expect(counter.calls, 1);
      expect(jsonDecode(await copy.readAsString()), {'calls': 1});
      expect(copy.statusCode, 201);
      expect(copy.body(), same(counter));
    });

    test('a response without body gets no Content-Type', () {
      final copy = ResponseEntity<String>.unauthorized().copyWith(
        statusCode: 403,
      );
      final changed = ResponseEntity<String>.unauthorized().copyWith(
        headers: {'x': '1'},
      );

      expect(copy.headers.containsKey(HttpHeader.contentType), isFalse);
      expect(changed.headers.containsKey(HttpHeader.contentType), isFalse);
      expect(changed.headers['x'], '1');
    });
  });

  group('ResponseEntity copyWith a new body', () {
    test(
      'the Content-Type and Content-Length are the ones of the new body',
      () {
        final json = ResponseEntity<Object>(200, body: {'a': 1});
        final text = json.copyWith(body: 'text');
        final bytes = json.copyWith(body: Uint8List.fromList([1, 2]));

        expect(
          text.headers[HttpHeader.contentType],
          '${MediaType.textPlain.mimeType}; charset=utf-8',
        );
        expect(text.headers[HttpHeader.contentLength], '4');
        expect(
          bytes.headers[HttpHeader.contentType],
          MediaType.applicationOctetStream.mimeType,
        );
        expect(bytes.headers[HttpHeader.contentLength], '2');
      },
    );

    test('a Content-Type given with the new body wins', () {
      final copy = ResponseEntity<Object>(200, body: 1).copyWith(
        body: '<p>hi</p>',
        headers: {HttpHeader.contentType: 'text/html'},
      );

      expect(copy.headers[HttpHeader.contentType], 'text/html');
    });
  });

  group('RequestEntity route', () {
    test('it can only be set once', () {
      final request = RequestEntity('GET', Uri.parse('http://x/users/1'));
      final route = Route.get(
        path: '/users/{id}',
        key: 'user',
        handler: (r) => ResponseEntity.ok(),
      );
      attachRoute(request, route);

      expect(request.route, same(route));
      expect(() => attachRoute(request, route), throwsStateError);
    });

    test('a template that does not match the url gives no path params', () {
      final request = RequestEntity('GET', Uri.parse('http://x/items/1'));
      attachRoute(
        request,
        Route.get(
          path: '/users/{id}',
          key: 'user',
          handler: (r) => ResponseEntity.ok(),
        ),
      );

      expect(request.pathParams, isEmpty);
    });

    test('query params', () {
      final request = RequestEntity(
        'GET',
        Uri.parse('http://x/search?q=dart&page=2'),
      );

      expect(request.queryParams, {'q': 'dart', 'page': '2'});
      expect(request.httpMethod, HttpMethod.get);
    });

    test('repeated query params', () {
      final request = RequestEntity(
        'GET',
        Uri.parse('http://x/search?tag=a&q=dart&tag=b'),
      );

      expect(request.queryParams, {'tag': 'b', 'q': 'dart'});
      expect(request.queryParamsAll, {
        'tag': ['a', 'b'],
        'q': ['dart'],
      });
      expect(
        RequestEntity('GET', Uri.parse('http://x/')).queryParamsAll,
        isEmpty,
      );
    });
  });
}

class _CountingBody {
  int calls = 0;
  Object? toJson() => {'calls': ++calls};
}

final ContextKey<String> _auth = ContextKey<String>('auth');
final ContextKey<bool> _cache = ContextKey<bool>('cache');
