@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../../bin/winter/winter.dart';

void main() {
  int port = 9022;
  String localUrl = 'http://localhost:$port';

  setUpAll(
    () async {
      await Winter.run(
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
          ],
        ),
      );
    },
  );

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  ///No auth header provided, give a 401 (test on route #1)
  test('Test No Auth Filter', () async {
    String urlToTest = '/mixed-filter/55';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 401);
  });

  ///No auth header provided, give a 401 (test on route #1)
  test('Test No Auth Filter', () async {
    String urlToTest = '/mixed-filter/2/55';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 401);
  });

  ///Auth header provided, give 200, second filter remove params, give body without params
  test('Test Route filter after pass auth filter', () async {
    String urlToTest = '/mixed-filter/55';
    http.Response response = await http.get(
      url(urlToTest),
      headers: {HttpHeaders.AUTHORIZATION: 'Bearer 123456'},
    );
    expect(response.statusCode, 200);

    ///body with empty params
    expect(response.body, 'path: {}, query: {}');
  });

  ///Auth header provided, give 200, no second filter, return body with params
  test('Test Route filter after pass auth filter', () async {
    String urlToTest = '/mixed-filter/2/55?some=123&another=963';
    http.Response response = await http.get(
      url(urlToTest),
      headers: {HttpHeaders.AUTHORIZATION: 'Bearer 123456'},
    );
    expect(response.statusCode, 200);

    ///body with current params (not removed by filter)
    expect(response.body, 'path: {id: 55}, query: {some: 123, another: 963}');
  });
}

class InterceptNotAuthRequestsFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (!request.headers.containsKey(HttpHeaders.AUTHORIZATION)) {
      return ResponseEntity(
        401,
        body: 'Request need the ${HttpHeaders.AUTHORIZATION} header',
      );
    }
    return await chain.doFilter(request);
  }
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
