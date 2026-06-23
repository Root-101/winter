@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9054;
  String localUrl = 'http://localhost:$port';

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port),
      router: WinterRouter(
        routes: [
          Route(
            path: '/parent',
            filterConfig: FilterConfig([
              AddHeaderFilter('X-Parent-Filter', 'parent'),
            ]),
            routes: [
              Route(
                path: '/child-1',
                method: HttpMethod.get,
                filterConfig: FilterConfig([
                  AddHeaderFilter('X-Child-Filter', 'child-1'),
                ]),
                handler: (request) => ResponseEntity.ok(
                  body: 'Return from response /parent/child-1',
                ),
              ),
              Route(
                path: '/child-2',
                method: HttpMethod.get,
                handler: (request) => ResponseEntity.ok(
                  body: 'Return from response /parent/child-2',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test /parent/child-1 (Both filters)', () async {
    String urlToTest = '/parent/child-1';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /parent/child-1');

    // Both parent and child filters should have executed
    expect(response.headers['x-parent-filter'], 'parent');
    expect(response.headers['x-child-filter'], 'child-1');
  });

  test('Test /parent/child-2 (Only parent filter)', () async {
    String urlToTest = '/parent/child-2';
    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Return from response /parent/child-2');

    // Only parent filter should have executed
    expect(response.headers['x-parent-filter'], 'parent');
    expect(response.headers.containsKey('x-child-filter'), isFalse);
  });
}

class AddHeaderFilter implements Filter {
  final String name;
  final String value;

  AddHeaderFilter(this.name, this.value);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    ResponseEntity response = await chain.doFilter(request);
    return response.copyWith(headers: {...response.headers, name: value});
  }
}
