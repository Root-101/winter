@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

///Global filter that fails with 401 when the request has the header 'X-Fail-Filter'
class FailingGlobalFilter extends Filter {
  @override
  bool shouldFilter(RequestEntity request) =>
      request.headers.containsKey('X-Fail-Filter');

  @override
  FutureOr<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) {
    throw const UnauthorizedException();
  }
}

///Route filter that adds the status code it received as a header
class SeenStatusFilter extends Filter {
  @override
  FutureOr<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final response = await chain.doFilter(request);
    return response.copyWith(
      headers: {...response.headers, 'X-Seen-Status': '${response.statusCode}'},
    );
  }
}

void main() {
  late WinterTestClient client;
  const origin = 'http://localhost:3000';

  setUpAll(() async {
    client = WinterTestClient.build(
      securityConfig: SecurityConfig(cors: const CorsConfig()),
      globalFilterConfig: FilterConfig([FailingGlobalFilter()]),
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/ok',
            handler: (request) => ResponseEntity.ok(body: 'ok'),
          ),
          Route.get(
            path: '/not-found',
            handler: (request) => throw const NotFoundException(),
          ),
          Route.get(
            path: '/seen',
            handler: (request) => throw const ConflictException(),
            filterConfig: FilterConfig([SeenStatusFilter()]),
          ),
        ],
      ),
    );
  });

  test('CORS headers are present when the handler throws', () async {
    final response = await client.get(
      '/not-found',
      headers: {HttpHeader.origin: origin},
    );

    expect(response.statusCode, 404);
    expect(response.headers['access-control-allow-origin'], '*');
  });

  test('CORS headers are present when a global filter throws', () async {
    final response = await client.get(
      '/ok',
      headers: {HttpHeader.origin: origin, 'X-Fail-Filter': 'true'},
    );

    expect(response.statusCode, 401);
    expect(response.headers['access-control-allow-origin'], '*');
  });

  test('Route filters receive the error response of the handler', () async {
    final response = await client.get('/seen');

    expect(response.statusCode, 409);
    expect(response.headers['x-seen-status'], '409');
  });

  test('Successful requests are not affected', () async {
    final response = await client.get(
      '/ok',
      headers: {HttpHeader.origin: origin},
    );

    expect(response.statusCode, 200);
    expect(response.body, 'ok');
    expect(response.headers['access-control-allow-origin'], '*');
  });
}
