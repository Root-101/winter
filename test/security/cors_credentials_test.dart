import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  const origin = 'http://localhost:3000';

  Future<ResponseEntity> runCors(CorsConfig config, {String? method}) async {
    final filter = CorsFilter(config: config);
    final chain = FilterChain([], (request) => ResponseEntity.ok());
    final request = RequestEntity(
      method ?? 'GET',
      Uri.parse('http://localhost/test'),
      headers: {HttpHeader.origin: origin},
    );
    return filter.doFilter(request, chain);
  }

  group('CORS with credentials', () {
    test('Wildcard origin with credentials echoes the origin', () async {
      final response = await runCors(const CorsConfig(allowCredentials: true));

      expect(response.headers[HttpHeader.accessControlAllowOrigin], origin);
      expect(
        response.headers[HttpHeader.accessControlAllowCredentials],
        'true',
      );
      expect(response.headers[HttpHeader.vary], HttpHeader.origin);
    });

    test('Wildcard origin without credentials stays as *', () async {
      final response = await runCors(const CorsConfig());

      expect(response.headers[HttpHeader.accessControlAllowOrigin], '*');
      expect(response.headers[HttpHeader.vary], isNull);
    });

    test('Not allowed origin gets no Allow-Origin header', () async {
      final response = await runCors(
        const CorsConfig(
          allowedOrigins: ['https://example.com'],
          allowCredentials: true,
        ),
      );

      expect(response.headers[HttpHeader.accessControlAllowOrigin], isNull);
    });
  });

  group('CORS headers', () {
    test('exposed headers are sent', () async {
      final response = await runCors(
        const CorsConfig(exposedHeaders: ['X-Total', 'X-Page']),
      );

      expect(
        response.headers[HttpHeader.accessControlExposeHeaders],
        'X-Total, X-Page',
      );
    });

    test(
      'preflight with allowedHeaders * echoes the requested headers',
      () async {
        final filter = CorsFilter(config: const CorsConfig(maxAge: 600));
        final preflight = RequestEntity(
          'OPTIONS',
          Uri.parse('http://localhost/test'),
          headers: {
            HttpHeader.origin: origin,
            HttpHeader.accessControlRequestMethod: 'POST',
            HttpHeader.accessControlRequestHeaders: 'X-Custom, Content-Type',
          },
        );

        final response = await filter.doFilter(
          preflight,
          FilterChain([], (request) => ResponseEntity.ok()),
        );

        expect(
          response.headers[HttpHeader.accessControlAllowHeaders],
          'X-Custom, Content-Type',
        );
        expect(response.headers[HttpHeader.accessControlMaxAge], '600');
        expect(
          response.headers[HttpHeader.accessControlAllowMethods],
          contains('POST'),
        );
      },
    );

    test('without Origin no CORS header is added', () async {
      final filter = CorsFilter();
      final response = await filter.doFilter(
        RequestEntity('GET', Uri.parse('http://localhost/test')),
        FilterChain([], (request) => ResponseEntity.ok()),
      );

      expect(response.headers[HttpHeader.accessControlAllowOrigin], isNull);
    });
  });
}
