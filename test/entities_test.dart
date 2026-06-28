import 'dart:convert';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('RequestEntity copyWith', () {
    test('should return an object with identical fields when no parameters are provided', () async {
      final uri = Uri.parse('http://localhost/test?q=1');
      final original = RequestEntity(
        'POST',
        uri,
        headers: {'content-type': 'text/plain', 'x-custom': 'value'},
        context: {'auth': 'token123'},
        body: 'hello world',
      );

      // Ensure body is read and cached
      await original.body<String>();

      final copy = await original.copyWith();

      // Check basic Request fields
      expect(copy.method, equals(original.method));
      expect(copy.requestedUri, equals(original.requestedUri));
      expect(copy.headers, equals(original.headers));
      expect(copy.url, equals(original.url));
      expect(copy.handlerPath, equals(original.handlerPath));
      expect(copy.protocolVersion, equals(original.protocolVersion));
      expect(copy.encoding, equals(original.encoding));
      
      // Check RequestEntity specific fields
      expect(copy.context, equals(original.context));
      expect(copy.context, isNot(same(original.context)), reason: 'Context should be a new map instance');
      
      // Check body
      expect(await copy.body<String>(), equals(await original.body<String>()));

      // Check derived fields
      expect(copy.queryParams, equals(original.queryParams));
      expect(copy.pathParams, equals(original.pathParams));
      expect(copy.httpMethod.name, equals(original.httpMethod.name));
    });

    test('should copy routing context and recalculate path params', () async {
      final original = RequestEntity(
        'GET',
        Uri.parse('http://localhost/users/123'),
      );
      
      final routingCtx = RequestRoutingContext(
        path: '/users/{id}',
        key: 'user_detail',
        method: HttpMethod.get,
      );
      
      original.setRoutingContext(routingCtx);
      expect(original.pathParams, equals({'id': '123'}));

      final copy = await original.copyWith();
      
      expect(copy.routingContext, isNotNull);
      expect(copy.routingContext!.key, equals('user_detail'));
      expect(copy.pathParams, equals({'id': '123'}));
    });

    test('should allow overriding fields', () async {
      final original = RequestEntity(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'a': 'b'},
      );

      final copy = await original.copyWith(
        headers: {'c': 'd'},
        context: {'new': 'ctx'},
        body: 'new body',
      );

      expect(copy.headers, containsPair('c', 'd'));
      expect(copy.headers, isNot(containsPair('a', 'b')));
      expect(copy.context, equals({'new': 'ctx'}));
      expect(await copy.body<String>(), equals('new body'));
    });
  });

  group('ResponseEntity copyWith', () {
    test('should return an object with identical fields when no parameters are provided', () {
      final original = ResponseEntity<Map>(
        200,
        body: {'id': 1},
        headers: {'content-type': 'application/json'},
        context: {'cache': true},
      );

      final copy = original.copyWith();

      expect(copy, isA<ResponseEntity<Map>>());
      expect(copy.statusCode, equals(original.statusCode));
      expect(copy.headers, equals(original.headers));
      expect(copy.context, equals(original.context));
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
        context: {'modified': true},
      );

      expect(copy.statusCode, equals(201));
      expect(copy.body(), equals('new'));
      expect(copy.headers['x-res'], equals('val'));
      expect(copy.context['modified'], isTrue);
    });
  });
}
