@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(() async {
    /// The 401 and the 403 of AuthFilter are exceptions: on<T>() changes their response
    Winter.context.setUp(
      exceptionHandler: SimpleExceptionHandler()
        ..on<UnauthorizedException>(
          (request, e) =>
              const UnauthorizedException(detail: 'Custom 401 message'),
        )
        ..on<ForbiddenException>(
          (request, e) =>
              const ForbiddenException(detail: 'Custom 403 message'),
        ),
    );
    client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route(
            path: '/unauthorized',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              MockAuthFilter(setAuth: false),
              AuthFilter(authenticated: true),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/forbidden-by-rules',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              MockAuthFilter(roles: {'user'}),
              AuthFilter(rules: hasRole('admin')),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/forbidden-by-auth-state',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              MockAuthFilter(authenticated: false),
              AuthFilter(authenticated: true),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/anonymous-by-rules',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              MockAuthFilter(setAuth: false),
              AuthFilter(authenticated: false, rules: hasRole('admin')),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/success',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              MockAuthFilter(roles: {'admin'}),
              AuthFilter(rules: hasRole('admin')),
            ]),
            handler: (request) async => ResponseEntity.ok(body: 'Success'),
          ),
        ],
      ),
    );
  });

  tearDownAll(() async {
    await Winter.close(force: true);
    Winter.context.setUp(exceptionHandler: SimpleExceptionHandler());
  });

  test(
    'Should return custom body for 401 with on<UnauthorizedException>',
    () async {
      TestResponse response = await client.get('/unauthorized');

      expect(response.statusCode, 401);
      expect(response.body, contains('Custom 401 message'));
      expect(response.body, contains('Unauthorized'));
      expect(
        response.headers['content-type'],
        contains('application/problem+json'),
      );
    },
  );

  test('Should return custom body for 403 when rules fail with on<ForbiddenException>', () async {
    TestResponse response = await client.get('/forbidden-by-rules');

    expect(response.statusCode, 403);
    expect(response.body, contains('Custom 403 message'));
    expect(response.body, contains('Forbidden'));
    expect(
      response.headers['content-type'],
      contains('application/problem+json'),
    );
  });

  test('Should return 401 when authenticated=false but authentication present (not logged in)', () async {
    TestResponse response = await client.get('/forbidden-by-auth-state');

    expect(response.statusCode, 401);
    expect(response.body, contains('Custom 401 message'));
    expect(
      response.headers['content-type'],
      contains('application/problem+json'),
    );
  });

  test(
    'Should return 401 when an anonymous user does not match the rules',
    () async {
      TestResponse response = await client.get('/anonymous-by-rules');

      expect(response.statusCode, 401);
    },
  );

  test('Should work normally when authentication passes', () async {
    TestResponse response = await client.get('/success');

    expect(response.statusCode, 200);
    expect(response.body, contains('Success'));
  });
}

/// A helper filter to simulate different authentication states
class MockAuthFilter extends Filter {
  final bool authenticated;
  final Set<String> roles;
  final bool setAuth;

  MockAuthFilter({
    this.authenticated = true,
    this.roles = const {},
    this.setAuth = true,
  });

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (setAuth) {
      request.securityContext.setAuthentication(
        Authentication(
          principal: 'TestUser',
          authenticated: authenticated,
          roles: roles,
        ),
      );
    } else {
      request.securityContext.clear();
    }
    return chain.doFilter(request);
  }
}
