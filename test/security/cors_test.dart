@TestOn('vm')
library;

import 'dart:io';

import 'package:http/http.dart' as http;
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
  int port = 9022;
  String localUrl = 'http://localhost:$port';

  group('CORS Tests', () {
    tearDown(() async {
      await Winter.close(force: true);
    });

    test(
      'Should NOT have CORS headers when SecurityConfig returns null',
      () async {
        await Winter.start(
          config: ServerConfig(port: port),
          securityConfig: SecurityConfig(), // Default returns null
          router: WinterRouter(
            routes: [
              Route(
                path: '/test',
                method: HttpMethod.get,
                handler: (req) => ResponseEntity.ok(body: 'ok'),
              ),
            ],
          ),
        );

        final response = await http.get(Uri.parse('$localUrl/test'));
        expect(response.statusCode, 200);
        expect(
          response.headers.containsKey(HttpHeaders.accessControlAllowOrigin),
          isFalse,
        );
      },
    );

    test('Should have default CORS headers when enabled', () async {
      await Winter.start(
        config: ServerConfig(port: port),
        securityConfig: SecurityConfig(cors: const CorsConfig()),
        router: WinterRouter(
          routes: [
            Route(
              path: '/test',
              method: HttpMethod.get,
              handler: (req) => ResponseEntity.ok(body: 'ok'),
            ),
          ],
        ),
      );

      final response = await http.get(
        Uri.parse('$localUrl/test'),
        headers: {HttpHeaders.origin: 'http://localhost:3000'},
      );
      expect(response.statusCode, 200);
      // http package headers are lowercase
      expect(
        response.headers[HttpHeaders.accessControlAllowOrigin.toLowerCase()],
        '*',
      );
    });

    test('Should handle Preflight (OPTIONS) request', () async {
      await Winter.start(
        config: ServerConfig(port: port),
        securityConfig: SecurityConfig(cors: const CorsConfig()),
        router: WinterRouter(
          routes: [
            Route(
              path: '/test',
              method: HttpMethod.get,
              handler: (req) => ResponseEntity.ok(body: 'ok'),
            ),
          ],
        ),
      );

      // Manual OPTIONS request to simulate preflight
      final request = await HttpClient().openUrl(
        'OPTIONS',
        Uri.parse('$localUrl/test'),
      );
      request.headers.add(HttpHeaders.accessControlRequestMethod, 'GET');
      request.headers.add(HttpHeaders.origin, 'http://localhost:3000');
      final response = await request.close();

      expect(response.statusCode, 200);
      expect(response.headers.value(HttpHeaders.accessControlAllowOrigin), '*');
      expect(
        response.headers.value(HttpHeaders.accessControlAllowMethods),
        contains('GET'),
      );
      expect(
        response.headers.value(HttpHeaders.accessControlAllowMethods),
        contains('POST'),
      );
    });

    test('Should apply custom CORS configuration', () async {
      await Winter.start(
        config: ServerConfig(port: port),
        securityConfig: CustomCorsSecurityConfig(),
        router: WinterRouter(
          routes: [
            Route(
              path: '/test',
              method: HttpMethod.post,
              handler: (req) => ResponseEntity.ok(body: 'ok'),
            ),
          ],
        ),
      );

      // Preflight
      final preflightRequest = await HttpClient().openUrl(
        'OPTIONS',
        Uri.parse('$localUrl/test'),
      );
      preflightRequest.headers.add(
        HttpHeaders.accessControlRequestMethod,
        'POST',
      );
      preflightRequest.headers.add(HttpHeaders.origin, 'https://example.com');
      final preflightResponse = await preflightRequest.close();

      expect(preflightResponse.statusCode, 200);
      expect(
        preflightResponse.headers.value(HttpHeaders.accessControlAllowOrigin),
        'https://example.com',
      );
      expect(
        preflightResponse.headers.value(HttpHeaders.accessControlAllowMethods),
        'GET, POST',
      );
      expect(
        preflightResponse.headers.value(HttpHeaders.accessControlAllowHeaders),
        isNotNull,
      );
      expect(
        preflightResponse.headers.value(
          HttpHeaders.accessControlAllowCredentials,
        ),
        'true',
      );
      expect(
        preflightResponse.headers.value(HttpHeaders.accessControlMaxAge),
        '3600',
      );

      // Actual request
      final response = await http.post(
        Uri.parse('$localUrl/test'),
        headers: {HttpHeaders.origin: 'https://example.com'},
      );
      expect(response.statusCode, 200);
      expect(
        response.headers[HttpHeaders.accessControlAllowOrigin.toLowerCase()],
        'https://example.com',
      );
      expect(
        response.headers[HttpHeaders.accessControlAllowCredentials
            .toLowerCase()],
        'true',
      );
    });

    test('Should NOT allow origin if not in custom list', () async {
      await Winter.start(
        config: ServerConfig(port: port),
        securityConfig: CustomCorsSecurityConfig(),
        router: WinterRouter(
          routes: [
            Route(
              path: '/test',
              method: HttpMethod.get,
              handler: (req) => ResponseEntity.ok(body: 'ok'),
            ),
          ],
        ),
      );

      final response = await http.get(
        Uri.parse('$localUrl/test'),
        headers: {HttpHeaders.origin: 'https://malicious.com'},
      );
      expect(response.statusCode, 200);
      expect(
        response.headers.containsKey(HttpHeaders.accessControlAllowOrigin),
        isFalse,
      );
    });
  });
}
