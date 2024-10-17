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
              path: '/filter-chain/{id}',
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

  test('get sync/async handler', () async {
    http.Response response = await http.get(url('/filter-chain/{id}'));
    expect(response.statusCode, 200);
    expect(response.body, 'path: {}, query: {}'); //body with empty
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
