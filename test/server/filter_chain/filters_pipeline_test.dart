@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Filters through the whole pipeline: global and route filters, their order, what they change,
/// short-circuits, errors and shouldFilter. The FilterChain alone is in filter_chain_test.dart.
void main() {
  group('Global and route filters', () {
    final client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([
        _Block(),
        _Trace('global'),
        _ResponseHeader('x-global'),
      ]),
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/plain/{id}',
            handler: (request) => ResponseEntity.ok(body: _describe(request)),
          ),
          Route.get(
            path: '/no-query/{id}',
            filterConfig: FilterConfig([_RemoveQuery()]),
            handler: (request) => ResponseEntity.ok(body: _describe(request)),
          ),
          Route.get(
            path: '/traced',
            filterConfig: FilterConfig([_Trace('A'), _Trace('B')]),
            handler: (request) =>
                ResponseEntity.ok(body: request.headers['x-trace']),
          ),
          Route.get(
            path: '/denied',
            filterConfig: FilterConfig([_Deny()]),
            handler: (request) => ResponseEntity.ok(body: 'not reached'),
          ),
          Route.get(
            path: '/changed',
            filterConfig: FilterConfig([_AppendToBody(' modified')]),
            handler: (request) => ResponseEntity.ok(body: 'Original'),
          ),
        ],
      ),
    );

    test('a global filter runs for every route, and for a 404', () async {
      expect((await client.get('/plain/1')).headers['x-global'], 'true');
      final notFound = await client.get('/nowhere');
      expect(notFound.statusCode, 404);
      expect(notFound.headers['x-global'], 'true');
    });

    test('a route filter only for its route', () async {
      expect(
        (await client.get('/no-query/55?a=1')).body,
        'path: {id: 55}, query: {}',
      );
      expect(
        (await client.get('/plain/55?a=1&b=2')).body,
        'path: {id: 55}, query: {a: 1, b: 2}',
      );
    });

    test('the changed request keeps its decoded path params', () async {
      expect(
        (await client.get('/no-query/hello%20world?a=1')).body,
        'path: {id: hello world}, query: {}',
      );
    });

    test('the global ones first, then the route ones in their order', () async {
      expect((await client.get('/traced')).body, 'global,A,B');
    });

    test('a response changed after the chain', () async {
      expect((await client.get('/changed')).body, 'Original modified');
    });

    test(
      'a route filter that short-circuits: the handler never runs',
      () async {
        final response = await client.get('/denied');

        expect(response.statusCode, 403);
        expect(response.body, 'Access Denied');
        // The global filters around it still see its response
        expect(response.headers['x-global'], 'true');
      },
    );

    test('a global filter that short-circuits skips the later ones', () async {
      final response = await client.get(
        '/plain/1',
        headers: {'x-block': 'true'},
      );

      expect(response.statusCode, 401);
      expect(response.body, 'Blocked by filter');
      expect(response.headers, isNot(contains('x-global')));
    });
  });

  group('Errors inside the chain', () {
    final client = WinterTestClient.build(
      securityConfig: SecurityConfig(cors: const CorsConfig()),
      globalFilterConfig: FilterConfig([_FailWhenAsked()]),
      router: WinterRouter(
        routes: [
          Route.get(path: '/ok', handler: (request) => ResponseEntity.ok()),
          Route.get(
            path: '/conflict',
            filterConfig: FilterConfig([_SeenStatus()]),
            handler: (request) => throw const ConflictException(),
          ),
          Route.get(
            path: '/broken',
            filterConfig: FilterConfig([_Broken()]),
            handler: (request) => ResponseEntity.ok(),
          ),
        ],
      ),
    );
    const Map<String, String> origin = {'origin': 'https://app.example.com'};

    test(
      'a route filter gets the error of the handler as a response',
      () async {
        final response = await client.get('/conflict');

        expect(response.statusCode, 409);
        expect(response.headers['x-seen-status'], '409');
      },
    );

    test('CORS is on the error of a handler and of a global filter', () async {
      final fromHandler = await client.get('/nowhere', headers: origin);
      final fromFilter = await client.get(
        '/ok',
        headers: {...origin, 'x-fail': 'true'},
      );

      expect(fromHandler.statusCode, 404);
      expect(fromHandler.headers['access-control-allow-origin'], '*');
      expect(fromFilter.statusCode, 401);
      expect(fromFilter.headers['access-control-allow-origin'], '*');
    });

    test(
      'a filter that fails with a bug is a 500 without its message',
      () async {
        final response = await client.get('/broken');

        expect(response.statusCode, 500);
        expect(response.body, isNot(contains('filter bug')));
      },
    );
  });

  group('shouldFilter', () {
    final client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([
        _ResponseHeader(
          'x-by-key',
          shouldFilter: (request) => request.route?.key == 'keyed',
        ),
        _ResponseHeader(
          'x-by-path',
          shouldFilter: (request) =>
              request.requestedUri.path.startsWith('/api/'),
        ),
      ]),
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/keyed',
            key: 'keyed',
            handler: (request) => ResponseEntity.ok(),
          ),
          Route.get(path: '/api/x', handler: (request) => ResponseEntity.ok()),
          Route.get(path: '/other', handler: (request) => ResponseEntity.ok()),
        ],
      ),
    );

    test('by the key of the route', () async {
      expect((await client.get('/keyed')).headers['x-by-key'], 'true');
      expect((await client.get('/other')).headers['x-by-key'], isNull);
    });

    test('by the path', () async {
      expect((await client.get('/api/x')).headers['x-by-path'], 'true');
      expect((await client.get('/other')).headers['x-by-path'], isNull);
    });
  });

  group('Headers added by filters around the body', () {
    final _Counter counter = _Counter();
    const Map<String, String> origin = {'origin': 'https://app.example.com'};
    final client = WinterTestClient.build(
      securityConfig: SecurityConfig(
        cors: const CorsConfig(allowedOrigins: ['https://app.example.com']),
      ),
      globalFilterConfig: FilterConfig([
        RateLimiterFilter(
          maxRequests: 1000,
          window: const Duration(minutes: 1),
        ),
      ]),
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/bytes',
            filterConfig: FilterConfig([_ReplaceBody()]),
            handler: (request) => ResponseEntity.ok(body: 'old body'),
          ),
          Route.get(
            path: '/object',
            handler: (request) => ResponseEntity.ok(body: counter),
          ),
          Route.get(
            path: '/vary',
            handler: (request) =>
                ResponseEntity.ok(headers: {HttpHeader.vary: 'Cookie'}),
          ),
          Route.get(path: '/empty', handler: (request) => ResponseEntity(401)),
        ],
      ),
    );

    test('a body of bytes set with copyWith is kept', () async {
      final response = await client.get('/bytes', headers: origin);

      expect(response.body, 'new body');
      expect(response.headers['access-control-allow-origin'], origin['origin']);
      expect(response.headers['x-ratelimit-limit'], '1000');
    });

    test('an object body is serialized once, whatever the filters', () async {
      expect((await client.get('/object', headers: origin)).json, {'calls': 1});
      expect(counter.calls, 1);
    });

    test('the Vary of CORS is merged with the one of the response', () async {
      expect(
        (await client.get('/vary', headers: origin)).headers['vary'],
        'Cookie, Origin',
      );
    });

    test('a response without body gets no Content-Type', () async {
      final response = await client.get('/empty', headers: origin);

      expect(response.statusCode, 401);
      expect(response.body, isEmpty);
      expect(response.headers, isNot(contains('content-type')));
    });
  });
}

String _describe(RequestEntity request) =>
    'path: ${request.pathParams}, query: ${request.queryParams}';

/// Adds its name to the `x-trace` header of the request
class _Trace extends Filter {
  final String name;

  _Trace(this.name);

  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) {
    final String? trace = request.headers['x-trace'];
    return Future.value(
      chain.doFilter(
        request.copyWith(
          headers: {'x-trace': trace == null ? name : '$trace,$name'},
        ),
      ),
    );
  }
}

class _RemoveQuery extends Filter {
  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) =>
      Future.value(
        chain.doFilter(
          request.copyWith(
            requestedUri: request.requestedUri.replace(query: ''),
          ),
        ),
      );
}

/// Adds `name: true` to the response
class _ResponseHeader extends Filter {
  final String name;
  final bool Function(RequestEntity request)? _shouldFilter;

  _ResponseHeader(this.name, {this._shouldFilter});

  @override
  bool shouldFilter(RequestEntity request) =>
      _shouldFilter?.call(request) ?? true;

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async => (await chain.doFilter(request)).copyWith(headers: {name: 'true'});
}

class _Block extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (request.headers['x-block'] == 'true') {
      return ResponseEntity(401, body: 'Blocked by filter');
    }
    return chain.doFilter(request);
  }
}

class _Deny extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async => ResponseEntity(403, body: 'Access Denied');
}

class _AppendToBody extends Filter {
  final String suffix;

  _AppendToBody(this.suffix);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final ResponseEntity response = await chain.doFilter(request);
    return response.copyWith(body: '${await response.readAsString()}$suffix');
  }
}

class _FailWhenAsked extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (request.headers['x-fail'] == 'true') {
      throw const UnauthorizedException();
    }
    return chain.doFilter(request);
  }
}

class _SeenStatus extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final ResponseEntity response = await chain.doFilter(request);
    return response.copyWith(
      headers: {'x-seen-status': '${response.statusCode}'},
    );
  }
}

class _Broken extends Filter {
  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) =>
      throw StateError('filter bug');
}

class _ReplaceBody extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async =>
      (await chain.doFilter(request))
          .copyWith(body: Uint8List.fromList('new body'.codeUnits));
}

/// Counts how many times it's serialized
class _Counter {
  int calls = 0;

  Map<String, int> toJson() => {'calls': ++calls};
}
