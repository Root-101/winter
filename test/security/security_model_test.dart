import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('Authentication', () {
    final authentication = Authentication<int>(
      principal: 42,
      roles: {'admin'},
      permissions: {'user.list'},
    );

    test('name, roles and permissions', () {
      expect(authentication.name, '42');
      expect(authentication.roles, {'admin'});
      expect(authentication.permissions, {'user.list'});
    });

    test('roles & permissions are unmodifiable', () {
      expect(() => authentication.roles.add('x'), throwsUnsupportedError);
      expect(() => authentication.permissions.add('x'), throwsUnsupportedError);
    });

    test('copyWith changes only the given fields', () {
      final copy = authentication.copyWith(
        authenticated: false,
        roles: {'user'},
      );

      expect(copy.principal, 42);
      expect(copy.authenticated, isFalse);
      expect(copy.roles, {'user'});
      expect(copy.permissions, {'user.list'});
      expect(authentication.copyWith().roles, authentication.roles);
    });

    test('anonymous is not authenticated', () {
      final anonymous = Authentication.anonymous();

      expect(anonymous.authenticated, isFalse);
      expect(anonymous.roles, isEmpty);
      expect(anonymous.permissions, isEmpty);
    });
  });

  group('RequestSecurityContext', () {
    test('is created on demand and shared by the request', () {
      final request = RequestEntity('GET', Uri.parse('http://x/'));

      expect(request.securityContext.isAuthenticated, isFalse);
      request.securityContext.setAuthentication(Authentication(principal: 'a'));
      expect(request.securityContext.isAuthenticated, isTrue);

      request.securityContext.clearContext();
      expect(request.securityContext.authentication, isNull);
    });
  });

  group('Rules', () {
    final authentication = Authentication(
      principal: 'adam',
      roles: {'admin'},
      permissions: {'user.list'},
    );

    test('a role or a permission (what hasAuthority was)', () {
      expect(
        (hasRole('admin') | hasPermission('admin')).evaluate(
          authentication,
          _request,
        ),
        isTrue,
      );
      expect(
        (hasRole('user.list') | hasPermission('user.list')).evaluate(
          authentication,
          _request,
        ),
        isTrue,
      );
      expect(
        (hasRole('other') | hasPermission('other')).evaluate(
          authentication,
          _request,
        ),
        isFalse,
      );
    });

    test('toString shows the expression', () {
      expect(const RoleRule('admin').toString(), 'hasRole(admin)');
      expect(
        (hasRole('admin') & (hasPermission('a') | hasRole('b'))).toString(),
        'hasRole(admin) && (hasPermission(a) || hasRole(b))',
      );
    });

    test('AuthFilter.toString shows its configuration', () {
      expect(
        AuthFilter(rules: hasRole('admin')).toString(),
        'AuthFilter{authenticated: true, rules: hasRole(admin), shouldFilter: all}',
      );
      expect(
        AuthFilter(shouldFilter: (request) => false).toString(),
        contains('shouldFilter: custom'),
      );
    });
  });
}

/// The rules of these tests don't look at the request
final RequestEntity _request = RequestEntity(
  'GET',
  Uri.parse('http://localhost/'),
);
