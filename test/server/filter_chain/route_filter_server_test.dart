@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9023;
  String localUrl = 'http://localhost:$port';

  setUpAll(
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

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test Route Filter', () async {
    String urlToTest = '/route-filter/55?some=123&another=963';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 200);

    ///body with empty params
    expect(response.body, 'path: {}, query: {}');
  });

  test('Test Route Filter #2', () async {
    String urlToTest = '/route-filter/2/55?some=123&another=963';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 200);

    ///body with current params (not removed by filter)
    expect(response.body, 'path: {id: 55}, query: {some: 123, another: 963}');
  });
}

///This filter remove the path & query params of the request
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
