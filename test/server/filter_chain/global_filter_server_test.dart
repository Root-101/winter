@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9021;
  String localUrl = 'http://localhost:$port';

  setUpAll(() async {
    await Winter.run(
      config: ServerConfig(port: port),
      globalFilterConfig: FilterConfig([
        BlockFilter(),
        InterceptFilter(),
        AddGlobalHeaderFilter(),
        RemoveQueryParamsFilter(),
      ]),
      router: WinterRouter(
        routes: [
          Route(
            path: '/global-filter/{id}',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(
              body:
                  'path: ${request.pathParams}, query: ${request.queryParams}',
            ),
          ),
          Route(
            path: '/global-filter/2/{id}',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(
              body:
                  'path: ${request.pathParams}, query: ${request.queryParams}',
            ),
          ),
          Route(
            path: '/no-params',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(body: 'no params here'),
          ),
          Route(
            path: '/local-filter',
            method: HttpMethod.get,
            filterConfig: FilterConfig([LocalFilter()]),
            handler: (request) => ResponseEntity.ok(body: 'local filter test'),
          ),
          Route(
            path: '/will-be-intercepted',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(body: 'should not reach'),
          ),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  group('Global Filter Tests', () {
    test('Test Global Filter clears params on /global-filter/{id}', () async {
      String urlToTest = '/global-filter/55?some=123&another=963';
      http.Response response = await http.get(url(urlToTest));
      expect(response.statusCode, 200);
      expect(response.body, 'path: {}, query: {}');
      expect(response.headers['x-global-filter'], 'true');
    });

    test('Test Global Filter clears params on /global-filter/2/{id}', () async {
      String urlToTest = '/global-filter/2/66?some=456&another=852';
      http.Response response = await http.get(url(urlToTest));
      expect(response.statusCode, 200);
      expect(response.body, 'path: {}, query: {}');
      expect(response.headers['x-global-filter'], 'true');
    });

    test('Test Global Filter on route without params', () async {
      http.Response response = await http.get(url('/no-params'));
      expect(response.statusCode, 200);
      expect(response.body, 'no params here');
      expect(response.headers['x-global-filter'], 'true');
    });

    test('Test Global and Local Filter combination', () async {
      http.Response response = await http.get(url('/local-filter'));
      expect(response.statusCode, 200);
      expect(response.body, 'local filter test');
      expect(response.headers['x-global-filter'], 'true');
      expect(response.headers['x-local-filter'], 'true');
    });

    test('Test Intercepting Global Filter', () async {
      http.Response response = await http.get(url('/will-be-intercepted'));
      expect(response.statusCode, 200);
      expect(response.body, 'Intercepted by filter');
      // InterceptFilter is BEFORE AddGlobalHeaderFilter and doesn't call chain.doFilter
      expect(response.headers.containsKey('x-global-filter'), isFalse);
    });

    test('Test Blocking Global Filter', () async {
      http.Response response = await http.get(
        url('/no-params'),
        headers: {'x-block': 'true'},
      );
      expect(response.statusCode, 401);
      expect(response.body, 'Blocked by filter');
      expect(response.headers.containsKey('x-global-filter'), isFalse);
    });

    test('Test Global Filter runs even on 404', () async {
      http.Response response = await http.get(url('/non-existent-route'));
      expect(response.statusCode, 404);
      expect(response.headers['x-global-filter'], 'true');
    });
  });
}

class RemoveQueryParamsFilter implements Filter {
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

class AddGlobalHeaderFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final response = await chain.doFilter(request);
    return response.copyWith(
      headers: {...response.headers, 'x-global-filter': 'true'},
    );
  }
}

class InterceptFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (request.requestedUri.path == '/will-be-intercepted') {
      return ResponseEntity.ok(body: 'Intercepted by filter');
    }
    return await chain.doFilter(request);
  }
}

class BlockFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (request.headers['x-block'] == 'true') {
      return ResponseEntity(
        HttpStatus.unauthorized.value,
        body: 'Blocked by filter',
      );
    }
    return await chain.doFilter(request);
  }
}

class LocalFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final response = await chain.doFilter(request);
    return response.copyWith(
      headers: {...response.headers, 'x-local-filter': 'true'},
    );
  }
}
