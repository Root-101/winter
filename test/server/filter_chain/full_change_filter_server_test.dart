@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../../bin/winter.dart';

void main() {
  int port = 9020;
  String localUrl = 'http://localhost:$port';

  setUpAll(
    () async {
      await Winter.run(
        config: ServerConfig(port: port),
        globalFilterConfig: FilterConfig([FullChangeFilterFilter()]),
        router: WinterRouter(
          routes: [
            Route(
              path: '/full-change-filter',
              method: HttpMethod.post,
              handler: (request) async {
                return ResponseEntity.ok(
                  body: await request.body<String>(),
                  headers: {
                    'before-request-header':
                        request.headers['before-request-header'] ?? '',
                  },
                );
              },
            ),
          ],
        ),
      );
    },
  );

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test Full Change Filter', () async {
    String urlToTest = '/full-change-filter';

    String body = 'Hello world!!!';
    http.Response response = await http.post(url(urlToTest), body: body);

    expect(response.statusCode, 200);
    expect(response.body, body);
    expect(response.headers['before-request-header'], 'before-request');
    expect(response.headers['after-request-header'], 'after-request');
  });
}

class FullChangeFilterFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    RequestEntity newRequestEntity = request.copyWith(
      headers: {
        ...request.headers,
        'before-request-header': 'before-request',
      },
    );

    ResponseEntity newResponseEntity = await chain.doFilter(newRequestEntity);

    newResponseEntity = newResponseEntity.copyWith(
      headers: {
        ...newResponseEntity.headers,
        'after-request-header': 'after-request',
      },
    );

    return newResponseEntity;
  }
}
