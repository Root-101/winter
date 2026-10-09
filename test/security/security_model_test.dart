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

      request.securityContext.clear();
      expect(request.securityContext.authentication, isNull);
    });
  });
}
