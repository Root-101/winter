@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  Map<String, String> headers = {'SECRET': 'Secret', 'ACCESS': 'Access'};

  setUpAll(() async {
    client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([SecurityAccessFilter()]),
      router: WinterRouter(
        routes: [
          Route(
            path: '/with-auth',
            key: 'with-auth-key',
            method: HttpMethod.get,
            filterConfig: FilterConfig([AuthFilter()]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/without-auth',
            key: 'without-auth-key',
            method: HttpMethod.get,
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/with-authorities',
            key: 'with-authorities-key',
            method: HttpMethod.get,
            filterConfig: FilterConfig([AuthFilter(rules: hasRole('User'))]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/with-admin',
            key: 'with-admin-key',
            method: HttpMethod.get,
            filterConfig: FilterConfig([AuthFilter(rules: hasRole('admin'))]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/with-permission',
            key: 'with-permission-key',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              AuthFilter(rules: hasPermission('user.create')),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/with-combined-rules',
            key: 'with-combined-rules-key',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              AuthFilter(
                rules: hasRole('admin') & hasPermission('user.delete'),
              ),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/with-or-rules',
            key: 'with-or-rules-key',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              AuthFilter(rules: hasRole('guest') | hasRole('admin')),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/with-failed-combined',
            key: 'with-failed-combined-key',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              AuthFilter(
                rules: hasRole('admin') & hasPermission('user.update'),
              ),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/with-case-sensitive-role',
            key: 'with-case-sensitive-role-key',
            method: HttpMethod.get,
            filterConfig: FilterConfig([AuthFilter(rules: hasRole('ADMIN'))]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/with-authority',
            key: 'with-authority-key',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              AuthFilter(rules: (hasRole('admin') | hasPermission('admin'))),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/with-multiple-filters',
            key: 'with-multiple-filters-key',
            method: HttpMethod.get,
            filterConfig: FilterConfig([
              AuthFilter(rules: hasRole('admin')),
              AuthFilter(rules: hasPermission('user.create')),
            ]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/check-principal',
            key: 'check-principal-key',
            method: HttpMethod.get,
            handler: (request) async => ResponseEntity.ok(
              body: request.securityContext.authentication?.principal,
            ),
          ),
          Route(
            path: '/authenticated-false',
            key: 'authenticated-false-key',
            method: HttpMethod.get,
            filterConfig: FilterConfig([AuthFilter(authenticated: false)]),
            handler: (request) async => ResponseEntity.ok(),
          ),
        ],
      ),
    );
  });

  test('Test with auth success', () async {
    String urlToTest = '/with-auth';

    TestResponse response = await client.get(urlToTest, headers: headers);

    expect(response.statusCode, 200);
  });

  test('Test with auth fail', () async {
    String urlToTest = '/with-auth';

    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 401);
  });

  test('Test without auth success', () async {
    String urlToTest = '/without-auth';

    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
  });

  test('Test with authorities fail (Forbidden)', () async {
    String urlToTest = '/with-authorities';

    TestResponse response = await client.get(urlToTest, headers: headers);

    expect(response.statusCode, 403);
  });

  test('Test with authorities fail (Unauthorized)', () async {
    String urlToTest = '/with-authorities';

    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 401);
  });

  test('Test with admin success', () async {
    String urlToTest = '/with-admin';

    TestResponse response = await client.get(urlToTest, headers: headers);

    expect(response.statusCode, 200);
  });

  test('Test with permission success', () async {
    String urlToTest = '/with-permission';

    TestResponse response = await client.get(urlToTest, headers: headers);

    expect(response.statusCode, 200);
  });

  test('Test combined rules success', () async {
    String urlToTest = '/with-combined-rules';

    TestResponse response = await client.get(urlToTest, headers: headers);

    expect(response.statusCode, 200);
  });

  test('Test OR rules success', () async {
    String urlToTest = '/with-or-rules';

    TestResponse response = await client.get(urlToTest, headers: headers);

    expect(response.statusCode, 200);
  });

  test('Test combined rules fail (Forbidden)', () async {
    String urlToTest = '/with-failed-combined';

    TestResponse response = await client.get(urlToTest, headers: headers);

    expect(response.statusCode, 403);
  });

  test('Test case sensitive role fail (Forbidden)', () async {
    String urlToTest = '/with-case-sensitive-role';

    TestResponse response = await client.get(urlToTest, headers: headers);

    expect(response.statusCode, 403);
  });

  test('Test with wrong security headers (Unauthorized)', () async {
    String urlToTest = '/with-auth';

    TestResponse response = await client.get(
      urlToTest,
      headers: {'SECRET': 'Wrong', 'ACCESS': 'Wrong'},
    );

    expect(response.statusCode, 401);
  });

  test('Test with authority success', () async {
    String urlToTest = '/with-authority';

    TestResponse response = await client.get(urlToTest, headers: headers);

    expect(response.statusCode, 200);
  });

  test('Test with multiple filters success', () async {
    String urlToTest = '/with-multiple-filters';

    TestResponse response = await client.get(urlToTest, headers: headers);

    expect(response.statusCode, 200);
  });

  test('Test principal is set correctly', () async {
    String urlToTest = '/check-principal';

    TestResponse response = await client.get(urlToTest, headers: headers);

    expect(response.statusCode, 200);
    expect(response.body, 'Admin');
  });

  test('Test principal is null when no headers', () async {
    String urlToTest = '/check-principal';

    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
    expect(response.body, '');
  });

  test('Test authenticated false allows anonymous', () async {
    String urlToTest = '/authenticated-false';

    TestResponse response = await client.get(urlToTest);

    expect(response.statusCode, 200);
  });
}

class SecurityAccessFilter extends Filter {
  final String secretHeader = 'SECRET';
  final String accessHeader = 'ACCESS';

  late final String _envSecret;
  late final String _envAccess;

  SecurityAccessFilter() {
    _envSecret = 'Secret';
    _envAccess = 'Access';
  }

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    String? secret = request.headers[secretHeader];
    String? access = request.headers[accessHeader];
    if (secret != null &&
        access != null &&
        secret == _envSecret &&
        access == _envAccess) {
      request.securityContext.setAuthentication(
        Authentication(
          principal: 'Admin',
          roles: {'admin'},
          permissions: {'user.create', 'user.delete', 'user.list'},
        ),
      );
    } else {
      request.securityContext.clear();
    }

    return await chain.doFilter(request);
  }
}
