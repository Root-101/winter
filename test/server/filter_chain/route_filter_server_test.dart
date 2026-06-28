@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('Route Filter Tests', () {
    int port = 9023;
    String localUrl = 'http://localhost:$port';

    setUpAll(() async {
      await Winter.start(
        config: ServerConfig(port: port),
        router: WinterRouter(
          routes: [
            Route(
              path: '/route-filter/{id}',
              filterConfig: FilterConfig([RemoveQueryParamsFilter()]),
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(
                body:
                    'path: ${request.pathParams}, query: ${request.queryParams}',
              ),
            ),
            Route(
              path: '/route-filter/2/{id}',
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(
                body:
                    'path: ${request.pathParams}, query: ${request.queryParams}',
              ),
            ),
            Route(
              path: '/protected',
              filterConfig: FilterConfig([AuthFilter()]),
              method: HttpMethod.get,
              handler: (request) =>
                  ResponseEntity.ok(body: 'protected content'),
            ),
            Route(
              path: '/with-header',
              filterConfig: FilterConfig([AddResponseHeaderFilter()]),
              method: HttpMethod.get,
              handler: (request) =>
                  ResponseEntity.ok(body: 'content with header'),
            ),
            Route(
              path: '/modify-request',
              filterConfig: FilterConfig([ModifyRequestFilter()]),
              method: HttpMethod.get,
              handler: (request) =>
                  ResponseEntity.ok(body: request.headers['x-modified']),
            ),
            Route(
              path: '/filter-error',
              filterConfig: FilterConfig([ErrorFilter()]),
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(body: 'not reached'),
            ),
          ],
        ),
      );
    });

    tearDownAll(() => Winter.close(force: true));

    Uri url(String path) => Uri.parse(localUrl + path);

    test('Test Route Filter - Parameters removal', () async {
      String urlToTest = '/route-filter/55?some=123&another=963';
      http.Response response = await http.get(url(urlToTest));
      expect(response.statusCode, 200);

      ///body with empty params
      expect(response.body, 'path: {}, query: {}');
    });

    test('Test Route Filter #2 - No filters applied', () async {
      String urlToTest = '/route-filter/2/55?some=123&another=963';
      http.Response response = await http.get(url(urlToTest));
      expect(response.statusCode, 200);

      ///body with current params (not removed by filter)
      expect(response.body, 'path: {id: 55}, query: {some: 123, another: 963}');
    });

    test('Test Auth Filter - Unauthorized', () async {
      http.Response response = await http.get(url('/protected'));
      expect(response.statusCode, 401);
      expect(response.body, '{"message":"Unauthorized"}');
    });

    test('Test Auth Filter - Authorized', () async {
      http.Response response = await http.get(
        url('/protected'),
        headers: {'Authorization': 'Bearer my-token'},
      );
      expect(response.statusCode, 200);
      expect(response.body, 'protected content');
    });

    test('Test Add Response Header Filter', () async {
      http.Response response = await http.get(url('/with-header'));
      expect(response.statusCode, 200);
      expect(response.headers['x-added-by-filter'], 'true');
    });

    test('Test Modify Request Filter', () async {
      http.Response response = await http.get(url('/modify-request'));
      expect(response.statusCode, 200);
      expect(response.body, 'True');
    });

    test('Test Filter Error Handling', () async {
      http.Response response = await http.get(url('/filter-error'));
      expect(response.statusCode, 500);
    });
  });

  group('Global Filter Tests', () {
    int port = 9024;
    String localUrl = 'http://localhost:$port';

    setUpAll(() async {
      await Winter.start(
        config: ServerConfig(port: port),
        globalFilterConfig: FilterConfig([GlobalHeaderFilter()]),
        router: WinterRouter(
          routes: [
            Route(
              path: '/hello',
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(body: 'world'),
            ),
          ],
        ),
      );
    });

    tearDownAll(() => Winter.close(force: true));

    Uri url(String path) => Uri.parse(localUrl + path);

    test('Test Global Filter - Applied to all routes', () async {
      http.Response response = await http.get(url('/hello'));
      expect(response.statusCode, 200);
      expect(response.headers['x-global-filter'], 'applied');
    });
  });
}

///This filter remove the path & query params of the request
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

class AuthFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (request.headers['Authorization'] == null) {
      return ResponseEntity(401, body: {'message': 'Unauthorized'});
    }
    return await chain.doFilter(request);
  }
}

class AddResponseHeaderFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    ResponseEntity response = await chain.doFilter(request);
    return response.copyWith(
      headers: {...response.headers, 'X-Added-By-Filter': 'true'},
    );
  }
}

class AppendHeaderFilter extends Filter {
  final String name;
  final String value;

  AppendHeaderFilter(this.name, this.value);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    ResponseEntity response = await chain.doFilter(request);

    Map<String, Object> newHeaders = Map.from(response.headers);
    if (newHeaders.containsKey(name)) {
      newHeaders[name] = '${newHeaders[name]}, $value';
    } else {
      newHeaders[name] = value;
    }

    return response.copyWith(headers: newHeaders);
  }
}

class GlobalHeaderFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    ResponseEntity response = await chain.doFilter(request);
    return response.copyWith(
      headers: {...response.headers, 'X-Global-Filter': 'applied'},
    );
  }
}

class ModifyRequestFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final modifiedRequest = await request.copyWith(
      headers: {...request.headers, 'x-modified': 'True'},
    );
    return await chain.doFilter(modifiedRequest);
  }
}

class ErrorFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    throw Exception('Filter Error');
  }
}
