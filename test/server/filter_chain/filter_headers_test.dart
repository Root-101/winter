import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Counts how many times it's serialized
class _CountingBody {
  int calls = 0;
  Object? toJson() => {'calls': ++calls};
}

/// The filters that add headers (CORS, rate limiter) keep the body of the response as it is
void main() {
  const String origin = 'https://app.example.com';
  final counter = _CountingBody();

  final client = WinterTestClient.build(
    securityConfig: SecurityConfig(
      cors: const CorsConfig(allowedOrigins: [origin]),
    ),
    globalFilterConfig: FilterConfig([
      RateLimiterFilter(maxRequests: 1000, window: const Duration(minutes: 1)),
    ]),
    router: WinterRouter(
      routes: [
        Route.get(
          path: '/bytes',
          handler: (request) =>
              ResponseEntity<String>.ok(body: 'old')
                  .change(body: utf8.encode('new body')),
        ),
        Route.get(
          path: '/object',
          handler: (request) => ResponseEntity.ok(body: counter),
        ),
        Route.get(
          path: '/vary',
          handler: (request) => ResponseEntity.ok(
            body: 'x',
            headers: {HttpHeader.vary: 'Cookie'},
          ),
        ),
        Route.get(
          path: '/empty',
          handler: (request) => ResponseEntity.unauthorized(),
        ),
      ],
    ),
  );

  final Map<String, String> headers = {HttpHeader.origin: origin};

  test('A body set with change is kept', () async {
    final response = await client.get('/bytes', headers: headers);

    expect(response.statusCode, 200);
    expect(response.body, 'new body');
    expect(response.headers[HttpHeader.accessControlAllowOrigin], origin);
    expect(response.headers['X-RateLimit-Limit'], '1000');
  });

  test('An object body is serialized only once', () async {
    final response = await client.get('/object', headers: headers);

    expect(response.json, {'calls': 1});
    expect(counter.calls, 1);
  });

  test('The Vary of CORS is merged with the one of the response', () async {
    final response = await client.get('/vary', headers: headers);

    expect(response.headers[HttpHeader.vary], 'Cookie, Origin');
  });

  test('A response without body gets no Content-Type', () async {
    final response = await client.get('/empty', headers: headers);

    expect(response.statusCode, 401);
    expect(response.body, isEmpty);
    expect(response.headers.containsKey(HttpHeader.contentType), isFalse);
    expect(response.headers[HttpHeader.accessControlAllowOrigin], origin);
  });
}
