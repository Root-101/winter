@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  Map<String, String> adminHeaders = {
    'SECRET': 'SecretAdmin',
    'ACCESS': 'AccessAdmin',
  };

  Map<String, String> userHeaders = {
    'SECRET': 'SecretUser',
    'ACCESS': 'AccessUser',
  };

  setUpAll(() async {
    client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([
        CustomSecurityAccessFilter(),
        AuthFilter(
          authenticated: true,
          shouldFilter: (request) {
            // Whitelist: the global AuthFilter is not applied to the public route
            String? routeKey = request.route?.key;
            List<String> whiteList = ['public-route'];
            return !whiteList.contains(routeKey);
          },
        ),
      ]),
      router: WinterRouter(
        routes: [
          Route(
            path: '/private',
            key: 'private-route',
            method: HttpMethod.get,
            handler: (request) async =>
                ResponseEntity.ok(body: 'Private Content'),
          ),
          Route(
            path: '/public',
            key: 'public-route',
            method: HttpMethod.get,
            handler: (request) async =>
                ResponseEntity.ok(body: 'Public Content'),
          ),
          Route(
            path: '/admin',
            key: 'admin-route',
            method: HttpMethod.get,
            // Route filter to check the ADMIN role
            filterConfig: FilterConfig([AuthFilter(rules: hasRole('ADMIN'))]),
            handler: (request) async =>
                ResponseEntity.ok(body: 'Admin Content'),
          ),
        ],
      ),
    );
  });

  group('Global AuthFilter with Whitelist and Roles', () {
    test('Private route with valid headers returns 200', () async {
      final response = await client.get('/private', headers: adminHeaders);
      expect(response.statusCode, 200);
    });

    test('Public route returns 200 without headers', () async {
      final response = await client.get('/public');
      expect(response.statusCode, 200);
    });

    group('Role Based Access (/admin)', () {
      test('Access /admin with ADMIN role returns 200', () async {
        final response = await client.get('/admin', headers: adminHeaders);
        expect(response.statusCode, 200);
        expect(response.body, 'Admin Content');
      });

      test('Access /admin with USER role returns 403 (Forbidden)', () async {
        final response = await client.get('/admin', headers: userHeaders);
        // The user is authenticated but does not have the ADMIN role
        expect(response.statusCode, 403);
      });

      test(
        'Access /admin without headers returns 401 (Unauthorized)',
        () async {
          final response = await client.get('/admin');
          // The global AuthFilter fails before reaching the role filter
          expect(response.statusCode, 401);
        },
      );

      test('Access /admin with invalid headers returns 401', () async {
        final response = await client.get(
          '/admin',
          headers: {'SECRET': 'wrong', 'ACCESS': 'wrong'},
        );
        expect(response.statusCode, 401);
      });
    });
  });
}

class CustomSecurityAccessFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    String? secret = request.headers['SECRET'];
    String? access = request.headers['ACCESS'];

    if (secret == 'SecretAdmin' && access == 'AccessAdmin') {
      request.securityContext.setAuthentication(
        Authentication(principal: 'ADMIN_USER', roles: {'ADMIN', 'USER'}),
      );
    } else if (secret == 'SecretUser' && access == 'AccessUser') {
      request.securityContext.setAuthentication(
        Authentication(principal: 'REGULAR_USER', roles: {'USER'}),
      );
    } else {
      request.securityContext.clear();
    }

    return await chain.doFilter(request);
  }
}
