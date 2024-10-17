@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../../bin/winter/winter.dart';

void main() {
  int port = 9090;
  String localUrl = 'http://localhost:$port';

  setUp(
    () async {
      await Winter.run(
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
          ],
        ),
      );
    },
  );

  tearDown(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test Route Filter', () async {
    String urlToTest = '/route-filter/55?some=123&another=963';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 200);
    expect(response.body, 'path: {}, query: {}');

    ///body with empty params
  });

  test('Test Route Filter #2', () async {
    String urlToTest = '/route-filter/2/55?some=123&another=963';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 200);

    ///body with current params (not removed by filter)
    expect(response.body, 'path: {id: 55}, query: {some: 123, another: 963}');
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
