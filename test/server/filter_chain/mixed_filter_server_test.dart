@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9022;
  String localUrl = 'http://localhost:$port';

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port),
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

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  group('Global Filter Tests', () {
    test(
      'Should return 401 when Authorization header is missing (Route 1)',
      () async {
        String urlToTest = '/mixed-filter/55';
        http.Response response = await http.get(url(urlToTest));
        expect(response.statusCode, 401);
        expect(
          response.body,
          'Request need the ${HttpHeaders.authorization} header',
        );
      },
    );

    test(
      'Should return 401 when Authorization header is missing (Route 2)',
      () async {
        String urlToTest = '/mixed-filter/2/55';
        http.Response response = await http.get(url(urlToTest));
        expect(response.statusCode, 401);
      },
    );
  });

  group('Mixed Filter Tests (Global + Route)', () {
    final authHeaders = {HttpHeaders.authorization: 'Bearer 123456'};

    test(
      'Should remove params when RemoveQueryParamsFilter is present',
      () async {
        String urlToTest = '/mixed-filter/55?some=123';
        http.Response response = await http.get(
          url(urlToTest),
          headers: authHeaders,
        );
        expect(response.statusCode, 200);
        expect(response.body, 'path: {}, query: {}');
      },
    );

    test('Should keep params when no route filter is present', () async {
      String urlToTest = '/mixed-filter/2/55?some=123&another=963';
      http.Response response = await http.get(
        url(urlToTest),
        headers: authHeaders,
      );
      expect(response.statusCode, 200);
      expect(response.body, 'path: {id: 55}, query: {some: 123, another: 963}');
    });
  });

  group('Advanced Filter Tests', () {
    final authHeaders = {HttpHeaders.authorization: 'Bearer 123456'};

    test('Should add custom header to request via filter', () async {
      http.Response response = await http.get(
        url('/custom-header'),
        headers: authHeaders,
      );
      expect(response.statusCode, 200);
      expect(response.body, 'Winter-Value');
    });

    test('Should short-circuit request and return custom response', () async {
      http.Response response = await http.get(
        url('/short-circuit'),
        headers: authHeaders,
      );
      expect(response.statusCode, 403);
      expect(response.body, 'Access Denied');
    });

    test(
      'Should execute multiple filters in the order they are defined',
      () async {
        http.Response response = await http.get(
          url('/multi-filter'),
          headers: authHeaders,
        );
        expect(response.statusCode, 200);
        expect(response.body, 'AB');
      },
    );

    test('Should modify response after chain execution', () async {
      http.Response response = await http.get(
        url('/post-filter'),
        headers: authHeaders,
      );
      expect(response.statusCode, 200);
      expect(response.headers['x-post-filter'], 'true');
    });

    test(
      'Should correctly handle path params with special characters',
      () async {
        String urlToTest = '/mixed-filter/2/hello%20world';
        http.Response response = await http.get(
          url(urlToTest),
          headers: authHeaders,
        );
        expect(response.statusCode, 200);
        expect(response.body, contains('path: {id: hello%20world}, query: {}'));
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
    if (!request.headers.containsKey(HttpHeaders.authorization)) {
      return ResponseEntity(
        401,
        body: 'Request need the ${HttpHeaders.authorization} header',
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
    request.pathParams.clear();
    request.queryParams.clear();
    return await chain.doFilter(request);
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
    final newRequest = await request.copyWith(headers: newHeaders);
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
    final newRequest = await request.copyWith(headers: newHeaders);
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
