import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// `Deprecation` (RFC 9745), `Sunset` (RFC 8594) and their links
void main() {
  final DateTime deprecated = DateTime.utc(2026, 7);
  final DateTime sunset = DateTime.utc(2027);

  WinterTestClient client(DeprecationFilter filter) => WinterTestClient.build(
    router: WinterRouter(
      routes: [
        Route.parent(
          path: '/v1',
          filterConfig: FilterConfig([filter]),
          routes: [
            Route.get(
              path: '/users/{id}',
              handler: (request) => request.pathParam<int>('id') == 1
                  ? ResponseEntity.ok(
                      body: 'Ann',
                      headers: {HttpHeader.link: '</v1/users/2>; rel="next"'},
                    )
                  : throw const NotFoundException(),
            ),
          ],
        ),
        Route.get(path: '/v2/users/{id}', handler: (r) => ResponseEntity.ok()),
      ],
    ),
  );

  test('the children of the parent get the date, the sunset and the links', () async {
    final response = await client(
      DeprecationFilter(
        deprecated: deprecated,
        sunset: sunset,
        link: Uri.parse('https://api.example.com/docs/v2'),
        successor: (request) =>
            request.requestedUri.path.replaceFirst('/v1/', '/v2/'),
      ),
    ).get('/v1/users/1');

    expect(response.headers['deprecation'], '@1782864000');
    expect(response.headers['sunset'], 'Fri, 01 Jan 2027 00:00:00 GMT');
    // After the Link the handler gave
    expect(response.headersAll['link'], [
      '</v1/users/2>; rel="next"',
      '<https://api.example.com/docs/v2>; rel="deprecation"; type="text/html"',
      '</v2/users/1>; rel="successor-version"',
    ]);
  });

  test(
    'only Deprecation when nothing else is given, on the errors too',
    () async {
      final filter = DeprecationFilter(deprecated: deprecated);
      final ok = await client(filter).get('/v1/users/1');
      final missing = await client(filter).get('/v1/users/9');
      final other = await client(filter).get('/v2/users/1');

      expect(ok.headers, isNot(contains('sunset')));
      expect(ok.headersAll['link'], ['</v1/users/2>; rel="next"']);
      expect(missing.statusCode, 404);
      expect(missing.headers['deprecation'], '@1782864000');
      expect(other.headers, isNot(contains('deprecation')));
    },
  );

  test('a sunset before the deprecation is an ArgumentError', () {
    expect(
      () => DeprecationFilter(deprecated: sunset, sunset: deprecated),
      throwsArgumentError,
    );
  });
}
