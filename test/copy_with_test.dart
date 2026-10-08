import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('RequestEntity.copyWith', () {
    RequestEntity request({Object? body}) => RequestEntity(
      'POST',
      Uri.parse('http://localhost/api/users/42'),
      headers: {'x-original': 'yes'},
      body: body ?? '{"name":"Adam"}',
    );

    test('returns a RequestEntity with the new headers & context', () async {
      final changed = request().copyWith(
        headers: {'x-new': '1'},
        context: {'custom': 'value'},
      );

      expect(changed, isA<RequestEntity>());
      expect(changed.headers['x-original'], 'yes');
      expect(changed.headers['x-new'], '1');
      expect(changed.context['custom'], 'value');
      expect(await changed.body<String>(), '{"name":"Adam"}');
    });

    test('shares the body: it is read once, and cached for both', () async {
      final original = request();
      await original.body<Map<String, dynamic>>();

      final changed = original.copyWith(headers: {'x-new': '1'});

      expect(await changed.body<Map<String, dynamic>>(), {'name': 'Adam'});
    });

    test('a new body replaces the old one', () async {
      final changed = request().copyWith(body: 'new body');

      expect(await changed.body<String>(), 'new body');
    });

    test('keeps the routing & security context (and the path params)', () {
      final original = request();
      original.setRoutingContext(
        RequestRoutingContext(
          path: '/api/users/{id}',
          key: 'user',
          method: HttpMethod.post,
        ),
      );
      original.securityContext.setAuthentication(
        Authentication(principal: 'adam'),
      );

      final changed = original.copyWith(headers: {'x-new': '1'});

      expect(changed.pathParams, {'id': '42'});
      expect(changed.securityContext.authentication?.principal, 'adam');
    });
  });

  group('ResponseEntity.copyWith', () {
    test('keeps the body & value when only the headers change', () async {
      final response = ResponseEntity.ok(body: {'id': 1});

      final changed = response.copyWith(headers: {'x-new': '1'});

      expect(changed, isA<ResponseEntity<Map<String, int>>>());
      expect(changed.body(), {'id': 1});
      expect(changed.headers['x-new'], '1');
      expect(
        changed.headers['content-type'],
        'application/json; charset=utf-8',
      );
      expect(jsonDecode(await changed.readAsString()), {'id': 1});
    });

    test('a new body replaces the old one with the right length', () async {
      final response = ResponseEntity.ok(body: 'short');

      final changed = response.copyWith(body: 'a longer body');

      expect(await changed.readAsString(), 'a longer body');
      expect(changed.body(), 'a longer body');
      expect(changed.contentLength, 'a longer body'.length);
    });
  });
}
