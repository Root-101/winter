import 'dart:io' show HttpDate;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Conditional requests, RFC 9110 §13 (DECISIONS.md §10)
void main() {
  final DateTime modified = DateTime.utc(2026, 10, 1, 12);
  final String lastModified = HttpDate.format(modified);
  final String before = HttpDate.format(
    modified.subtract(const Duration(days: 1)),
  );
  final String after = HttpDate.format(modified.add(const Duration(days: 1)));

  group('A GET whose version the client has is a 304 by itself', () {
    final client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/etag',
            handler: (r) => ResponseEntity.ok(
              body: {'id': 7},
              headers: {
                HttpHeader.etag: '"v7"',
                HttpHeader.cacheControl: 'no-cache',
              },
            ),
          ),
          Route.get(
            path: '/dated',
            handler: (r) => ResponseEntity.ok(
              body: 'text',
              headers: {HttpHeader.lastModified: lastModified},
            ),
          ),
          Route.get(
            path: '/both',
            handler: (r) => ResponseEntity.ok(
              body: 'text',
              headers: {
                HttpHeader.etag: '"v7"',
                HttpHeader.lastModified: lastModified,
              },
            ),
          ),
          Route.post(
            path: '/etag',
            handler: (r) => ResponseEntity.ok(
              body: 'created',
              headers: {HttpHeader.etag: '"v7"'},
            ),
          ),
          Route.get(
            path: '/missing',
            handler: (r) => ResponseEntity(
              404,
              body: 'none',
              headers: {HttpHeader.etag: '"v7"'},
            ),
          ),
        ],
      ),
    );

    test('If-None-Match with its ETag (weak, in a list, or *)', () async {
      for (final ifNoneMatch in ['"v7"', 'W/"v7"', '"v6", "v7"', '*']) {
        final response = await client.get(
          '/etag',
          headers: {HttpHeader.ifNoneMatch: ifNoneMatch},
        );

        expect(response.statusCode, 304, reason: ifNoneMatch);
        expect(response.body, isEmpty);
        expect(response.headers['etag'], '"v7"');
        expect(response.headers['cache-control'], 'no-cache');
        expect(response.headers, isNot(contains('content-type')));
      }
      expect(
        (await client.head(
          '/etag',
          headers: {HttpHeader.ifNoneMatch: '"v7"'},
        )).statusCode,
        304,
      );
    });

    test(
      'another version, or no validator in the request, is the 200',
      () async {
        expect(
          (await client.get(
            '/etag',
            headers: {HttpHeader.ifNoneMatch: '"v6"'},
          )).statusCode,
          200,
        );
        expect((await client.get('/etag')).statusCode, 200);
      },
    );

    test('If-Modified-Since at or after its Last-Modified', () async {
      for (final (since, status) in [
        (lastModified, 304),
        (after, 304),
        (before, 200),
        ('not a date', 200),
      ]) {
        final response = await client.get(
          '/dated',
          headers: {HttpHeader.ifModifiedSince: since},
        );
        expect(response.statusCode, status, reason: since);
      }
    });

    test('If-None-Match wins over If-Modified-Since', () async {
      final response = await client.get(
        '/both',
        headers: {
          HttpHeader.ifNoneMatch: '"v6"',
          HttpHeader.ifModifiedSince: after,
        },
      );

      expect(response.statusCode, 200);
    });

    test('only a 200 of a GET or HEAD changes', () async {
      final header = {HttpHeader.ifNoneMatch: '"v7"'};

      expect((await client.post('/etag', headers: header)).statusCode, 200);
      expect((await client.get('/missing', headers: header)).statusCode, 404);
    });
  });

  group('checkPreconditions before a change', () {
    RequestEntity request(String method, Map<String, Object> headers) =>
        RequestEntity(
          method,
          Uri.parse('http://localhost/documents/1'),
          headers: headers,
        );

    Matcher throwsStatus(int status) => throwsA(
      isA<ApiException>().having((e) => e.statusCode, 'status', status),
    );

    test('If-Match: the same strong ETag passes, any other is a 412', () {
      request('PUT', {
        HttpHeader.ifMatch: '"v6", "v7"',
      }).checkPreconditions(etag: '"v7"');
      request('PUT', {
        HttpHeader.ifMatch: '*',
      }).checkPreconditions(etag: '"v7"');

      for (final (ifMatch, etag) in [
        ('"v6"', '"v7"'),
        ('W/"v7"', '"v7"'),
        ('"v7"', 'W/"v7"'),
        ('"v7"', null),
      ]) {
        expect(
          () => request('PUT', {
            HttpHeader.ifMatch: ifMatch,
          }).checkPreconditions(etag: etag),
          throwsStatus(412),
          reason: '$ifMatch against $etag',
        );
      }
    });

    test('If-Match: * fails for a resource that does not exist yet', () {
      expect(
        () => request('PUT', {
          HttpHeader.ifMatch: '*',
        }).checkPreconditions(exists: false),
        throwsStatus(412),
      );
    });

    test('If-Unmodified-Since: a 412 when it changed after that date', () {
      request('DELETE', {
        HttpHeader.ifUnmodifiedSince: lastModified,
      }).checkPreconditions(lastModified: modified);

      expect(
        () => request('DELETE', {
          HttpHeader.ifUnmodifiedSince: before,
        }).checkPreconditions(lastModified: modified),
        throwsStatus(412),
      );
      // If-Match is evaluated instead, when both come
      request('DELETE', {
        HttpHeader.ifMatch: '"v7"',
        HttpHeader.ifUnmodifiedSince: before,
      }).checkPreconditions(etag: '"v7"', lastModified: modified);
    });

    test('required: a change without a precondition is a 428', () {
      expect(
        () =>
            request('PUT', {}).checkPreconditions(etag: '"v7"', required: true),
        throwsStatus(428),
      );
      request('PUT', {
        HttpHeader.ifUnmodifiedSince: after,
      }).checkPreconditions(lastModified: modified, required: true);
    });

    test(
      'If-None-Match: * on a change is a 412 only if the resource exists',
      () {
        expect(
          () => request('PUT', {
            HttpHeader.ifNoneMatch: '*',
          }).checkPreconditions(etag: '"v7"'),
          throwsStatus(412),
        );
        request('PUT', {
          HttpHeader.ifNoneMatch: '*',
        }).checkPreconditions(exists: false);
      },
    );

    test('in a GET, a 304 with its validators', () {
      expect(
        () => request('GET', {
          HttpHeader.ifNoneMatch: '"v7"',
        }).checkPreconditions(etag: '"v7"', lastModified: modified),
        throwsA(
          isA<ResponseException>().having(
            (e) => (
              e.responseEntity.statusCode,
              e.responseEntity.headers['etag'],
              e.responseEntity.headers['last-modified'],
            ),
            'response',
            (304, '"v7"', lastModified),
          ),
        ),
      );
      expect(
        () => request('GET', {
          HttpHeader.ifModifiedSince: after,
        }).checkPreconditions(lastModified: modified),
        throwsA(isA<ResponseException>()),
      );
      request('GET', {}).checkPreconditions(etag: '"v7"');
    });
  });
}
