import 'package:security_examples/cors_with_credentials.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(
    router: router(),
    securityConfig: securityConfig,
  );
  const String app = 'https://app.example.com';

  test('the preflight of an allowed origin', () async {
    final response = await client.request(
      'OPTIONS',
      '/cart',
      headers: {
        'origin': app,
        'access-control-request-method': 'PUT',
        'access-control-request-headers': 'content-type',
      },
    );

    expect(response.statusCode, 200);
    expect(response.headers['access-control-allow-origin'], app);
    expect(response.headers['access-control-allow-credentials'], 'true');
    expect(response.headers['access-control-allow-methods'], contains('PUT'));
    expect(response.headers['access-control-max-age'], '600');
  });

  test('a call with the cookie: the app can read X-Cart-Count', () async {
    final response = await client.get(
      '/cart',
      headers: {'origin': app, 'cookie': 'session=abc'},
    );

    expect(response.statusCode, 200);
    expect(response.headers['access-control-allow-origin'], app);
    expect(
      response.headers['access-control-expose-headers'],
      contains('X-Cart-Count'),
    );
    expect(response.headers['vary'], contains('Origin'));
  });

  test('an error keeps the CORS headers, so the app can read it', () async {
    final response = await client.get('/cart', headers: {'origin': app});

    expect(response.statusCode, 401);
    expect(response.headers['access-control-allow-origin'], app);
  });

  test('another website gets no CORS headers: the browser blocks it', () async {
    final response = await client.get(
      '/cart',
      headers: {'origin': 'https://evil.example', 'cookie': 'session=abc'},
    );

    expect(response.headers['access-control-allow-origin'], isNull);
    expect(response.headers['vary'], contains('Origin'));
  });

  test('the session cookie works across sites', () async {
    final response = await client.get('/session');

    expect(
      response.headers['set-cookie'],
      allOf(
        contains('HttpOnly'),
        contains('Secure'),
        contains('SameSite=None'),
      ),
    );
  });
}
