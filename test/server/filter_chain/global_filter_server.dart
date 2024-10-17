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
        globalFilterConfig: FilterConfig(
          [RemoveQueryParamsFilter()],
        ),
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
          ],
        ),
      );
    },
  );

  tearDown(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test Global Filter', () async {
    String urlToTest = '/global-filter/55?some=123&another=963';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 200);
    expect(response.body, 'path: {}, query: {}'); //body with empty params
  });

  test('Test Global Filter #2', () async {
    String urlToTest = '/global-filter/66?some=456&another=852';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 200);
    expect(response.body, 'path: {}, query: {}'); //body with empty params
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
