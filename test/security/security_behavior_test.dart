@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The behavior decided in the review of the security (DECISIONS.md §8)
void main() {
  WinterTestClient clientWith({
    CorsConfig? cors,
    SecurityHeaders? securityHeaders,
    List<Route>? routes,
  }) => WinterTestClient.build(
    securityConfig: SecurityConfig(
      cors: cors,
      securityHeaders: securityHeaders,
    ),
    router: WinterRouter(
      routes:
          routes ??
          [
            Route.get(path: '/', handler: (r) => ResponseEntity.ok()),
            Route.get(path: '/error', handler: (r) => throw StateError('bug')),
          ],
    ),
  );

  group('CORS (§8)', () {
    test('"*" with credentials logs a warning (and still echoes)', () async {
      final logs = <String>[];
      Winter.context.setUp(logger: _MemoryLogger(logs));
      addTearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));

      final response = await clientWith(
        cors: const CorsConfig(allowCredentials: true),
      ).get('/', headers: {'origin': 'https://any.example'});

      expect(logs.single, contains('List the allowed origins'));
      expect(
        response.headers['access-control-allow-origin'],
        'https://any.example',
      );
    });

    test(
      'a list of origins varies by Origin, also for the ones not allowed',
      () async {
        final client = clientWith(
          cors: const CorsConfig(allowedOrigins: ['https://app.example']),
        );

        for (final origin in [
          'https://app.example',
          'https://evil.example',
          null,
        ]) {
          final response = await client.get('/', headers: {'origin': ?origin});

          expect(response.headers['vary'], contains('Origin'), reason: origin);
        }
      },
    );

    test('"*" without credentials does not vary by Origin', () async {
      final response = await clientWith(cors: const CorsConfig())
          .get('/', headers: {'origin': 'https://app.example'});

      expect(response.headers['access-control-allow-origin'], '*');
      expect(response.headers, isNot(contains('vary')));
    });

    test('X-Request-Id is exposed to the browser, once', () async {
      final response = await clientWith(
        cors: const CorsConfig(exposedHeaders: ['X-Request-Id', 'X-Total']),
      ).get('/', headers: {'origin': 'https://app.example'});

      expect(
        response.headers['access-control-expose-headers'],
        'X-Request-Id, X-Total',
      );
    });
  });

  group('AuthFilter (§8)', () {
    WinterTestClient authClient(AuthFilter filter) => clientWith(
      routes: [
        Route.get(
          path: '/',
          handler: (r) => ResponseEntity.ok(),
          filterConfig: FilterConfig([_SetUser(), filter]),
        ),
      ],
    );

    test(
      'a 401 has a WWW-Authenticate challenge (Bearer by default)',
      () async {
        final response = await authClient(AuthFilter()).get('/');

        expect(response.statusCode, 401);
        expect(response.headers['www-authenticate'], 'Bearer');
      },
    );

    test('the challenge can be another scheme', () async {
      final response = await authClient(
        AuthFilter(challenge: 'Basic realm="api"'),
      ).get('/');

      expect(response.headers['www-authenticate'], 'Basic realm="api"');
    });

    test(
      'an anonymous user that fails the rules gets the challenge too',
      () async {
        final response = await authClient(
          AuthFilter(authenticated: false, rules: hasRole('admin')),
        ).get('/');

        expect(response.statusCode, 401);
        expect(response.headers['www-authenticate'], 'Bearer');
      },
    );

    test('a 403 has no challenge: logging in again does not help', () async {
      final response = await authClient(AuthFilter(rules: hasRole('admin')))
          .get('/', headers: {'x-user': 'ann'});

      expect(response.statusCode, 403);
      expect(response.headers, isNot(contains('www-authenticate')));
    });
  });

  group('Rules that see the request (§8)', () {
    late WinterTestClient client;

    setUp(() {
      client = clientWith(
        routes: [
          Route.get(
            path: '/users/{id}',
            handler: (r) => ResponseEntity.ok(),
            filterConfig: FilterConfig([
              _SetUser(),
              AuthFilter(
                rules:
                    hasRole('admin') |
                    rule(
                      (auth, request) => request.pathParams['id'] == auth.name,
                      describe: 'isOwner',
                    ),
              ),
            ]),
          ),
        ],
      );
    });

    test('the owner and an admin pass, anyone else is a 403', () async {
      expect(
        (await client.get('/users/ann', headers: {'x-user': 'ann'})).statusCode,
        200,
      );
      expect(
        (await client.get(
          '/users/ann',
          headers: {'x-user': 'bob', 'x-role': 'admin'},
        )).statusCode,
        200,
      );
      expect(
        (await client.get('/users/ann', headers: {'x-user': 'bob'})).statusCode,
        403,
      );
    });

    test('a rule is printed with its description', () {
      final combined =
          hasRole('admin') | rule((a, r) => true, describe: 'isOwner');

      expect(combined.toString(), 'hasRole(admin) || isOwner');
      expect(rule((a, r) => true).toString(), 'rule');
    });

    test('a rule of the app can be printed (toString)', () {
      final combined = hasRole('admin') | _OwnerRule();

      expect(_OwnerRule().toString(), '_OwnerRule');
      expect(combined.toString(), 'hasRole(admin) || _OwnerRule');
      expect(AuthFilter(rules: combined).toString, returnsNormally);
    });
  });

  group('The typed principal (§8)', () {
    late WinterTestClient client;

    setUp(() {
      client = clientWith(
        routes: [
          Route.get(
            path: '/me',
            handler: (request) =>
                ResponseEntity.ok(body: _UserService().currentName()),
            filterConfig: FilterConfig([_SetUser()]),
          ),
          Route.get(
            path: '/public',
            handler: (request) => ResponseEntity.ok(
              body: request.principalOrNull<_User>()?.name ?? 'nobody',
            ),
            filterConfig: FilterConfig([_SetUser()]),
          ),
          Route.get(
            path: '/wrong-type',
            handler: (request) =>
                ResponseEntity.ok(body: request.principal<int>()),
            filterConfig: FilterConfig([_SetUser()]),
          ),
        ],
      );
    });

    test('requestPrincipal reads it from any code, with its type', () async {
      final response = await client.get('/me', headers: {'x-user': 'ann'});

      expect(response.body, 'ann');
    });

    test('nobody authenticated is a 401 with a challenge', () async {
      final response = await client.get('/me');

      expect(response.statusCode, 401);
      expect(response.headers['www-authenticate'], 'Bearer');
    });

    test('principalOrNull is null for nobody', () async {
      expect((await client.get('/public')).body, 'nobody');
      expect(
        (await client.get('/public', headers: {'x-user': 'ann'})).body,
        'ann',
      );
    });

    test('a principal of another type is a 500 (a bug of the app)', () async {
      final response = await client.get(
        '/wrong-type',
        headers: {'x-user': 'ann'},
      );

      expect(response.statusCode, 500);
    });

    test('request.principal is a 401 for nobody too', () async {
      final response = await client.get('/wrong-type');

      expect(response.statusCode, 401);
      expect(response.headers['www-authenticate'], 'Bearer');
    });

    test('outside a request there is none', () {
      expect(requestPrincipalOrNull<_User>(), isNull);
      expect(
        () => requestPrincipal<_User>(),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('an unauthenticated Authentication is nobody', () {
      final context = RequestSecurityContext<dynamic>.empty()
        ..setAuthentication(Authentication.anonymous());

      RequestScope.run(RequestScope(securityContext: context), () {
        expect(requestPrincipalOrNull<String>(), isNull);
      });
    });
  });

  group('Security headers (§8)', () {
    test('nosniff and DENY on every response, error ones included', () async {
      final client = clientWith();

      for (final path in ['/', '/error', '/missing']) {
        final response = await client.get(path);

        expect(
          response.headers['x-content-type-options'],
          'nosniff',
          reason: path,
        );
        expect(response.headers['x-frame-options'], 'DENY', reason: path);
        expect(response.headers, isNot(contains('content-security-policy')));
      }
    });

    test('a header set by the response is kept', () async {
      final client = clientWith(
        securityHeaders: const SecurityHeaders(),
        routes: [
          Route.get(
            path: '/',
            handler: (r) => ResponseEntity.ok(
              headers: {
                'X-Frame-Options': 'SAMEORIGIN',
                'Content-Security-Policy': "default-src 'self'",
              },
            ),
          ),
        ],
      );

      final response = await client.get('/');

      expect(response.headers['x-frame-options'], 'SAMEORIGIN');
      expect(response.headers['content-security-policy'], "default-src 'self'");
      expect(response.headers['referrer-policy'], 'no-referrer');
    });

    test(
      'SecurityHeaders adds Referrer-Policy and a CSP for an API, no HSTS',
      () async {
        final response = await clientWith(
          securityHeaders: const SecurityHeaders(),
        ).get('/error');

        expect(response.headers['referrer-policy'], 'no-referrer');
        expect(
          response.headers['content-security-policy'],
          "default-src 'none'; frame-ancestors 'none'",
        );
        expect(response.headers, isNot(contains('strict-transport-security')));
      },
    );

    test('HSTS only with hsts: true', () {
      expect(
        const SecurityHeaders(hsts: true).headers['Strict-Transport-Security'],
        'max-age=31536000',
      );
      expect(
        const SecurityHeaders(
          hsts: true,
          hstsMaxAge: Duration(days: 1),
          hstsIncludeSubDomains: true,
        ).headers['Strict-Transport-Security'],
        'max-age=86400; includeSubDomains',
      );
      expect(
        const SecurityHeaders(
          referrerPolicy: null,
          contentSecurityPolicy: null,
        ).headers,
        isEmpty,
      );
    });
  });
}

/// Authenticates the user of the header `x-user`, with the roles of `x-role`
class _SetUser extends Filter {
  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) {
    final name = request.headers['x-user'];
    if (name != null) {
      final role = request.headers['x-role'];
      request.securityContext.setAuthentication(
        Authentication<_User>(principal: _User(name), roles: {?role}),
      );
    }
    return Future.value(chain.doFilter(request));
  }
}

class _User {
  final String name;

  _User(this.name);

  @override
  String toString() => name;
}

/// A service: it reads the user of the request without receiving it
class _UserService {
  String currentName() => requestPrincipal<_User>().name;
}

class _OwnerRule extends AuthorizationRule {
  @override
  bool evaluate(Authentication authentication, RequestEntity request) => true;
}

class _MemoryLogger extends WinterLogger {
  final List<String> logs;

  _MemoryLogger(this.logs);

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => logs.add(message);
}
