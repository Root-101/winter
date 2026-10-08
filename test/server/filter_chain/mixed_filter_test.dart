@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(() async {
    client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([InterceptNotAuthRequestsFilter()]),
      router: WinterRouter(
        routes: [
          Route(
            path: '/mixed-filter/{id}',
            filterConfig: FilterConfig([RemoveQueryParamsFilter()]),
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(
              body:
                  'path: ${request.pathParams}, query: ${request.queryParams}',
            ),
          ),
          Route(
            path: '/mixed-filter/2/{id}',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(
              body:
                  'path: ${request.pathParams}, query: ${request.queryParams}',
            ),
          ),
          Route(
            path: '/custom-header',
            filterConfig: FilterConfig([AddCustomHeaderFilter()]),
            method: HttpMethod.get,
            handler: (request) =>
                ResponseEntity.ok(body: request.headers['X-Custom-Header']),
          ),
          Route(
            path: '/short-circuit',
            filterConfig: FilterConfig([ShortCircuitFilter()]),
            method: HttpMethod.get,
            handler: (request) =>
                ResponseEntity.ok(body: 'Should not reach here'),
          ),
          Route(
            path: '/multi-filter',
            filterConfig: FilterConfig([
              AppendToHeaderFilter('A'),
              AppendToHeaderFilter('B'),
            ]),
            method: HttpMethod.get,
            handler: (request) =>
                ResponseEntity.ok(body: request.headers['x-trace']),
          ),
          Route(
            path: '/post-filter',
            filterConfig: FilterConfig([PostFilter()]),
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(body: 'Success'),
          ),
        ],
      ),
    );
  });

  group('Global Filter Tests', () {
    test(
      'Should return 401 when Authorization header is missing (Route 1)',
      () async {
        String urlToTest = '/mixed-filter/55';
        TestResponse response = await client.get(urlToTest);
        expect(response.statusCode, 401);
        expect(
          response.body,
          'Request need the ${HttpHeader.authorization} header',
        );
      },
    );

    test(
      'Should return 401 when Authorization header is missing (Route 2)',
      () async {
        String urlToTest = '/mixed-filter/2/55';
        TestResponse response = await client.get(urlToTest);
        expect(response.statusCode, 401);
      },
    );
  });

  group('Mixed Filter Tests (Global + Route)', () {
    final authHeaders = {HttpHeader.authorization: 'Bearer 123456'};

    test(
      'Should remove params when RemoveQueryParamsFilter is present',
      () async {
        String urlToTest = '/mixed-filter/55?some=123';
        TestResponse response = await client.get(
          urlToTest,
          headers: authHeaders,
        );
        expect(response.statusCode, 200);
        expect(response.body, 'path: {id: 55}, query: {}');
      },
    );

    test('Should keep params when no route filter is present', () async {
      String urlToTest = '/mixed-filter/2/55?some=123&another=963';
      TestResponse response = await client.get(urlToTest, headers: authHeaders);
      expect(response.statusCode, 200);
      expect(response.body, 'path: {id: 55}, query: {some: 123, another: 963}');
    });
  });

  group('Advanced Filter Tests', () {
    final authHeaders = {HttpHeader.authorization: 'Bearer 123456'};

    test('Should add custom header to request via filter', () async {
      TestResponse response = await client.get(
        '/custom-header',
        headers: authHeaders,
      );
      expect(response.statusCode, 200);
      expect(response.body, 'Winter-Value');
    });

    test('Should short-circuit request and return custom response', () async {
      TestResponse response = await client.get(
        '/short-circuit',
        headers: authHeaders,
      );
      expect(response.statusCode, 403);
      expect(response.body, 'Access Denied');
    });

    test(
      'Should execute multiple filters in the order they are defined',
      () async {
        TestResponse response = await client.get(
          '/multi-filter',
          headers: authHeaders,
        );
        expect(response.statusCode, 200);
        expect(response.body, 'AB');
      },
    );

    test('Should modify response after chain execution', () async {
      TestResponse response = await client.get(
        '/post-filter',
        headers: authHeaders,
      );
      expect(response.statusCode, 200);
      expect(response.headers['x-post-filter'], 'true');
    });

    test(
      'Should correctly handle path params with special characters',
      () async {
        String urlToTest = '/mixed-filter/2/hello%20world';
        TestResponse response = await client.get(
          urlToTest,
          headers: authHeaders,
        );
        expect(response.statusCode, 200);
        expect(response.body, contains('path: {id: hello world}, query: {}'));
      },
    );
  });
}

class InterceptNotAuthRequestsFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (!request.headers.containsKey(HttpHeader.authorization)) {
      return ResponseEntity(
        401,
        body: 'Request need the ${HttpHeader.authorization} header',
      );
    }
    return await chain.doFilter(request);
  }
}

class RemoveQueryParamsFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    ///The request is read-only: the next filters get a copy without the query
    return await chain.doFilter(
      request.copyWith(requestedUri: request.requestedUri.replace(query: '')),
    );
  }
}

class AddCustomHeaderFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final newHeaders = Map<String, Object>.from(request.headers);
    newHeaders['X-Custom-Header'] = 'Winter-Value';
    final newRequest = request.copyWith(headers: newHeaders);
    return await chain.doFilter(newRequest);
  }
}

class ShortCircuitFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    return ResponseEntity(403, body: 'Access Denied');
  }
}

class AppendToHeaderFilter extends Filter {
  final String value;

  AppendToHeaderFilter(this.value);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final newHeaders = Map<String, Object>.from(request.headers);
    final current = newHeaders['x-trace'] ?? '';
    newHeaders['x-trace'] = '$current$value';
    final newRequest = request.copyWith(headers: newHeaders);
    return await chain.doFilter(newRequest);
  }
}

class PostFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    ResponseEntity response = await chain.doFilter(request);
    return response.copyWith(
      headers: {...response.headers, 'X-Post-Filter': 'true'},
    );
  }
}
