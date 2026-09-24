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
}
