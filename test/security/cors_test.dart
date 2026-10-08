@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

class CustomCorsSecurityConfig extends SecurityConfig {
  @override
  CorsConfig? cors() {
    return const CorsConfig(
      allowedOrigins: ['https://example.com'],
      allowedMethods: ['GET', 'POST'],
      allowedHeaders: ['Content-Type', 'X-Custom-Header'],
      allowCredentials: true,
      maxAge: 3600,
    );
  }
}

void main() {
  WinterTestClient clientWith(SecurityConfig securityConfig) =>
      WinterTestClient.build(
        securityConfig: securityConfig,
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/test',
              handler: (req) => ResponseEntity.ok(body: 'ok'),
            ),
            Route.post(
              path: '/test',
              handler: (req) => ResponseEntity.ok(body: 'ok'),
            ),
          ],
        ),
      );

  group('CORS through the pipeline', () {
    test('no CORS headers when SecurityConfig has no CORS', () async {
      final response = await clientWith(SecurityConfig())
          .get('/test', headers: {HttpHeader.origin: 'http://localhost:3000'});

      expect(response.statusCode, 200);
      expect(
        response.headers.containsKey(HttpHeader.accessControlAllowOrigin),
        isFalse,
      );
    });

    test('the default configuration allows any origin', () async {
      final response = await clientWith(
        SecurityConfig(cors: const CorsConfig()),
      ).get('/test', headers: {HttpHeader.origin: 'http://localhost:3000'});

      expect(response.headers[HttpHeader.accessControlAllowOrigin], '*');
    });

    test('a preflight is answered before the router', () async {
      final response =
          await clientWith(SecurityConfig(cors: const CorsConfig())).request(
            'OPTIONS',
            '/test',
            headers: {
              HttpHeader.accessControlRequestMethod: 'GET',
              HttpHeader.origin: 'http://localhost:3000',
            },
          );

      expect(response.statusCode, 200);
      expect(response.headers[HttpHeader.accessControlAllowOrigin], '*');
      expect(
        response.headers[HttpHeader.accessControlAllowMethods],
        allOf(contains('GET'), contains('POST')),
      );
    });

    test('a SecurityConfig of the app (preflight and request)', () async {
      final client = clientWith(CustomCorsSecurityConfig());

      final preflight = await client.request(
        'OPTIONS',
        '/test',
        headers: {
          HttpHeader.accessControlRequestMethod: 'POST',
          HttpHeader.origin: 'https://example.com',
        },
      );
      expect(preflight.statusCode, 200);
      expect(
        preflight.headers[HttpHeader.accessControlAllowOrigin],
        'https://example.com',
      );
      expect(
        preflight.headers[HttpHeader.accessControlAllowMethods],
        'GET, POST',
      );
      expect(
        preflight.headers[HttpHeader.accessControlAllowHeaders],
        isNotNull,
      );
      expect(
        preflight.headers[HttpHeader.accessControlAllowCredentials],
        'true',
      );
      expect(preflight.headers[HttpHeader.accessControlMaxAge], '3600');

      final response = await client.post(
        '/test',
        headers: {HttpHeader.origin: 'https://example.com'},
      );
      expect(response.statusCode, 200);
      expect(
        response.headers[HttpHeader.accessControlAllowOrigin],
        'https://example.com',
      );
      expect(
        response.headers[HttpHeader.accessControlAllowCredentials],
        'true',
      );
    });

    test('an origin out of the list gets no Allow-Origin', () async {
      final response = await clientWith(CustomCorsSecurityConfig())
          .get('/test', headers: {HttpHeader.origin: 'https://malicious.com'});

      expect(response.statusCode, 200);
      expect(
        response.headers.containsKey(HttpHeader.accessControlAllowOrigin),
        isFalse,
      );
    });
  });

  group('CorsFilter alone', () {
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
        final response = await runCors(
          const CorsConfig(allowCredentials: true),
        );

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
          // X-Request-Id is always exposed
          'X-Request-Id, X-Total, X-Page',
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
  });
}
