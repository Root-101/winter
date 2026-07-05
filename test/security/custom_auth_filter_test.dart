@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// A custom implementation of AuthFilter that overrides build401 and build403
/// to return a response with a body.
class CustomAuthFilter extends AuthFilter {
  CustomAuthFilter({super.authenticated, super.rules});

  @override
  ResponseEntity build401(RequestEntity request) {
    return ResponseEntity.unauthorized(
      body: {'error': 'Unauthorized', 'message': 'Custom 401 message'},
    );
  }

  @override
  ResponseEntity build403(RequestEntity request) {
    return ResponseEntity.forbidden(
      body: {'error': 'Forbidden', 'message': 'Custom 403 message'},
    );
  }
}

void main() {
  int port = 9086;
  String localUrl = 'http://localhost:$port';

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port),
      router: WinterRouter(
        routes: [
          Route(
            path: '/unauthorized',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              MockAuthFilter(setAuth: false),
              CustomAuthFilter(authenticated: true),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/forbidden-by-rules',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              MockAuthFilter(roles: {'user'}),
              CustomAuthFilter(rules: hasRole('admin')),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/forbidden-by-auth-state',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              MockAuthFilter(authenticated: false),
              CustomAuthFilter(authenticated: true),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/success',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              MockAuthFilter(roles: {'admin'}),
              CustomAuthFilter(rules: hasRole('admin')),
            ]),
            handler: (request) async => ResponseEntity.ok(body: 'Success'),
          ),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Should return custom body for 401 when extending AuthFilter', () async {
    http.Response response = await http.get(url('/unauthorized'));

    expect(response.statusCode, 401);
    expect(response.body, contains('Custom 401 message'));
    expect(response.body, contains('Unauthorized'));
    expect(
      response.headers['content-type'],
      contains('application/problem+json'),
    );
  });

  test(
    'Should return custom body for 403 when rules fail and extending AuthFilter',
    () async {
      http.Response response = await http.get(url('/forbidden-by-rules'));

      expect(response.statusCode, 403);
      expect(response.body, contains('Custom 403 message'));
      expect(response.body, contains('Forbidden'));
      expect(
        response.headers['content-type'],
        contains('application/problem+json'),
      );
    },
  );

  test(
    'Should return custom body for 403 when authenticated=false but authentication present',
    () async {
      http.Response response = await http.get(url('/forbidden-by-auth-state'));

      expect(response.statusCode, 403);
      expect(response.body, contains('Custom 403 message'));
      expect(
        response.headers['content-type'],
        contains('application/problem+json'),
      );
    },
  );

  test('Should work normally when authentication passes', () async {
    http.Response response = await http.get(url('/success'));

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
      request.securityContext.clearContext();
    }
    return chain.doFilter(request);
  }
}
