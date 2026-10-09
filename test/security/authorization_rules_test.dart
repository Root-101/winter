import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The rules on their own (evaluate and describe). Rules that read the request and their use in
/// AuthFilter are in security_behavior_test.dart and auth_filter_test.dart.
void main() {
  final user = Authentication(
    principal: 'ann',
    roles: {'User', 'SuperUser'},
    permissions: {'user.create', 'user.edit'},
  );

  bool check(AuthorizationRule rule, [Authentication? authentication]) =>
      rule.evaluate(authentication ?? user, _request);

  test(
    'hasRole looks only at the roles, hasPermission only at the permissions',
    () {
      expect(check(hasRole('User')), isTrue);
      expect(check(hasRole('user.create')), isFalse);
      expect(check(hasPermission('user.create')), isTrue);
      expect(check(hasPermission('User')), isFalse);
    },
  );

  test('a role or a permission, as one rule', () {
    RuleBuilder authority(String name) => hasRole(name) | hasPermission(name);

    expect(check(authority('User')), isTrue);
    expect(check(authority('user.create')), isTrue);
    expect(check(authority('Admin')), isFalse);
  });

  test('names are case sensitive', () {
    expect(check(hasRole('user')), isFalse);
    expect(check(hasPermission('USER.CREATE')), isFalse);
  });

  test('& and |', () {
    expect(check(hasRole('User') & hasPermission('user.edit')), isTrue);
    expect(check(hasRole('User') & hasRole('Admin')), isFalse);
    expect(check(hasRole('Admin') | hasRole('User')), isTrue);
    expect(check(hasRole('Admin') | hasRole('Guest')), isFalse);
    expect(
      check(hasRole('User') & hasPermission('user.create') & hasRole('Admin')),
      isFalse,
    );
  });

  test('& binds tighter than |, as in Dart', () {
    // Admin | (User & user.create)
    expect(
      check(hasRole('Admin') | hasRole('User') & hasPermission('user.create')),
      isTrue,
    );
    // Admin | (User & user.delete)
    expect(
      check(hasRole('Admin') | hasRole('User') & hasPermission('user.delete')),
      isFalse,
    );
    // (Admin | User) & (user.delete | user.edit)
    expect(
      check(
        (hasRole('Admin') | hasRole('User')) &
            (hasPermission('user.delete') | hasPermission('user.edit')),
      ),
      isTrue,
    );
  });

  test('anonymous, or no roles nor permissions: every rule fails', () {
    for (final Authentication nobody in [
      Authentication.anonymous(),
      Authentication(principal: 'empty'),
    ]) {
      expect(check(hasRole('User'), nobody), isFalse);
      expect(check(hasPermission('user.create'), nobody), isFalse);
    }
  });

  test('the same rule for different users', () {
    final rule = hasRole('Admin') | hasPermission('sudo');

    expect(
      check(rule, Authentication(principal: 'a', roles: {'Admin'})),
      isTrue,
    );
    expect(
      check(rule, Authentication(principal: 'r', permissions: {'sudo'})),
      isTrue,
    );
    expect(
      check(rule, Authentication(principal: 'j', roles: {'User'})),
      isFalse,
    );
  });

  test('toString shows the expression, with its parentheses', () {
    expect(const RoleRule('admin').toString(), 'hasRole(admin)');
    expect(
      (hasRole('admin') & (hasPermission('a') | hasRole('b'))).toString(),
      'hasRole(admin) && (hasPermission(a) || hasRole(b))',
    );
    expect(
      ((hasRole('Admin') | hasRole('User')) & hasPermission('read')).toString(),
      '(hasRole(Admin) || hasRole(User)) && hasPermission(read)',
    );
  });
}

/// The rules of these tests don't look at the request
final RequestEntity _request = RequestEntity(
  'GET',
  Uri.parse('http://localhost/'),
);
