@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// AuthFilter through the whole pipeline: who gets a 200, a 401 or a 403. The challenge of the
/// 401 is in security_behavior_test.dart, the logic of the rules in authorization_rules_test.dart.
void main() {
  /// `x-user: admin` (role admin, permissions user.create and user.delete), `x-user: user`
  /// (role user); anything else is nobody
  final Map<String, Map<String, String>> as = {
    'admin': {'x-user': 'admin'},
    'user': {'x-user': 'user'},
    'nobody': {},
    'wrong credentials': {'x-user': 'intruder'},
  };

  group('AuthFilter on a route', () {
    Route protected(String path, AuthFilter filter) => Route.get(
      path: path,
      filterConfig: FilterConfig([filter]),
      handler: (request) => ResponseEntity.ok(),
    );

    final client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([_UserHeaderFilter()]),
      router: WinterRouter(
        routes: [
          protected('/authenticated', AuthFilter()),
          protected('/role', AuthFilter(rules: hasRole('admin'))),
          protected('/role-upper-case', AuthFilter(rules: hasRole('ADMIN'))),
          protected(
            '/permission',
            AuthFilter(rules: hasPermission('user.create')),
          ),
          protected(
            '/and',
            AuthFilter(rules: hasRole('admin') & hasPermission('user.update')),
          ),
          protected(
            '/or',
            AuthFilter(rules: hasRole('guest') | hasRole('user')),
          ),
          protected('/anonymous-allowed', AuthFilter(authenticated: false)),
          Route.get(
            path: '/two-filters',
            filterConfig: FilterConfig([
              AuthFilter(rules: hasRole('admin')),
              AuthFilter(rules: hasPermission('user.create')),
            ]),
            handler: (request) => ResponseEntity.ok(),
          ),
          Route.get(
            path: '/public',
            handler: (request) => ResponseEntity.ok(
              body: request.securityContext.authentication?.principal,
            ),
          ),
        ],
      ),
    );

    // path → the status for admin, user, nobody and wrong credentials
    const Map<String, List<int>> expected = {
      '/authenticated': [200, 200, 401, 401],
      '/role': [200, 403, 401, 401],
      '/role-upper-case': [403, 403, 401, 401],
      '/permission': [200, 403, 401, 401],
      '/and': [403, 403, 401, 401],
      '/or': [403, 200, 401, 401],
      '/anonymous-allowed': [200, 200, 200, 200],
      '/two-filters': [200, 403, 401, 401],
      '/public': [200, 200, 200, 200],
    };

    for (final MapEntry(key: path, value: statuses) in expected.entries) {
      test(path, () async {
        final List<int> actual = [
          for (final Map<String, String> headers in as.values)
            (await client.get(path, headers: headers)).statusCode,
        ];

        expect(actual, statuses, reason: 'for ${as.keys.join(', ')}');
      });
    }

    test('the handler sees the principal, or none', () async {
      expect((await client.get('/public', headers: as['admin'])).body, 'admin');
      expect((await client.get('/public')).body, '');
    });
  });

  test(
    'an Authentication with authenticated: false is nobody: a 401',
    () async {
      final client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/',
              filterConfig: FilterConfig([
                _UserHeaderFilter(authenticated: false),
                AuthFilter(),
              ]),
              handler: (request) => ResponseEntity.ok(),
            ),
          ],
        ),
      );

      expect((await client.get('/', headers: as['admin'])).statusCode, 401);
    },
  );

  group('A global AuthFilter with exceptions by route key', () {
    final client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([
        _UserHeaderFilter(),
        AuthFilter(shouldFilter: (request) => request.route?.key != 'public'),
      ]),
      router: WinterRouter(
        routes: [
          Route.get(path: '/private', handler: (r) => ResponseEntity.ok()),
          Route.get(
            path: '/public',
            key: 'public',
            handler: (r) => ResponseEntity.ok(),
          ),
          Route.get(
            path: '/admin',
            filterConfig: FilterConfig([AuthFilter(rules: hasRole('admin'))]),
            handler: (r) => ResponseEntity.ok(),
          ),
        ],
      ),
    );

    Future<int> status(String path, String user) async =>
        (await client.get(path, headers: as[user])).statusCode;

    test('the public route needs nobody, the rest needs a user', () async {
      expect(await status('/public', 'nobody'), 200);
      expect(await status('/private', 'nobody'), 401);
      expect(await status('/private', 'user'), 200);
    });

    test(
      'the global one runs first: nobody is a 401 before the role',
      () async {
        expect(await status('/admin', 'nobody'), 401);
        expect(await status('/admin', 'user'), 403);
        expect(await status('/admin', 'admin'), 200);
      },
    );
  });

  group('on<T>() changes the 401 and the 403', () {
    setUpAll(
      () => Winter.context.setUp(
        exceptionHandler: SimpleExceptionHandler()
          ..on<UnauthorizedException>(
            (request, e) => const UnauthorizedException(detail: 'Log in first'),
          )
          ..on<ForbiddenException>(
            (request, e) => const ForbiddenException(detail: 'Admins only'),
          ),
      ),
    );

    tearDownAll(
      () => Winter.context.setUp(exceptionHandler: SimpleExceptionHandler()),
    );

    test('a Problem Details with the detail of the app', () async {
      final client = WinterTestClient.build(
        globalFilterConfig: FilterConfig([_UserHeaderFilter()]),
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/',
              filterConfig: FilterConfig([AuthFilter(rules: hasRole('admin'))]),
              handler: (r) => ResponseEntity.ok(),
            ),
          ],
        ),
      );

      final unauthorized = await client.get('/');
      final forbidden = await client.get('/', headers: as['user']);

      expect(unauthorized.statusCode, 401);
      expect((unauthorized.json as Map)['detail'], 'Log in first');
      expect(forbidden.statusCode, 403);
      expect((forbidden.json as Map)['detail'], 'Admins only');
      expect(forbidden.headers['content-type'], contains('problem+json'));
    });
  });

  test('toString shows its configuration', () {
    expect(
      AuthFilter(rules: hasRole('admin')).toString(),
      'AuthFilter{authenticated: true, rules: hasRole(admin), shouldFilter: all}',
    );
    expect(
      AuthFilter(shouldFilter: (request) => false).toString(),
      contains('shouldFilter: custom'),
    );
  });
}

/// Authenticates `x-user: admin` and `x-user: user`
class _UserHeaderFilter extends Filter {
  final bool authenticated;

  _UserHeaderFilter({this.authenticated = true});

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final Authentication? authentication = switch (request.headers['x-user']) {
      'admin' => Authentication(
        principal: 'admin',
        authenticated: authenticated,
        roles: {'admin'},
        permissions: {'user.create', 'user.delete'},
      ),
      'user' => Authentication(
        principal: 'user',
        authenticated: authenticated,
        roles: {'user'},
      ),
      _ => null,
    };
    if (authentication != null) {
      request.securityContext.setAuthentication(authentication);
    }
    return chain.doFilter(request);
  }
}
