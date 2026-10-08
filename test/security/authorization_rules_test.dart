import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('Authorization Rules Tests', () {
    late Authentication authentication;

    setUp(() {
      authentication = Authentication(
        principal: 'Test',
        roles: {'User', 'SuperUser'},
        permissions: {'user.create', 'user.edit', 'user.list'},
      );
    });

    test('authority >> User', () async {
      final rule = (hasRole('User') | hasPermission('User'));
      bool response = rule.evaluate(authentication, _request);

      expect(response, true);
    });

    test('authority >> user.create', () async {
      final rule = (hasRole('user.create') | hasPermission('user.create'));
      bool response = rule.evaluate(authentication, _request);

      expect(response, true);
    });

    test('role >> User', () async {
      final rule = hasRole('User');
      bool response = rule.evaluate(authentication, _request);

      expect(response, true);
    });

    test('role >> Admin', () async {
      final rule = hasRole('Admin');
      bool response = rule.evaluate(authentication, _request);

      expect(response, false);
    });

    test('permission >> user.create', () async {
      final rule = hasPermission('user.create');
      bool response = rule.evaluate(authentication, _request);

      expect(response, true);
    });

    test('permission >> user.delete', () async {
      final rule = hasPermission('user.delete');
      bool response = rule.evaluate(authentication, _request);

      expect(response, false);
    });

    test('permission >> User', () async {
      final rule = hasPermission('User');
      bool response = rule.evaluate(authentication, _request);

      expect(response, false);
    });

    test('role >> user.create', () async {
      final rule = hasRole('user.create');
      bool response = rule.evaluate(authentication, _request);

      expect(response, false);
    });

    test(
      'permission >> user.create && permission >> user.edit && role >> User',
      () async {
        final rule =
            hasPermission('user.create') &
            hasPermission('user.edit') &
            hasRole('User');
        bool response = rule.evaluate(authentication, _request);

        expect(response, true);
      },
    );

    test(
      'permission >> user.create && (role >> User && role >> SuperUser)',
      () async {
        final rule =
            hasPermission('user.create') &
            (hasRole('User') & hasRole('SuperUser'));
        bool response = rule.evaluate(authentication, _request);

        expect(response, true);
      },
    );

    test(
      'role >> User && (permission >> user.edit || permission >> "")',
      () async {
        final rule =
            hasRole('User') & (hasPermission('user.edit') | hasPermission(''));
        bool response = rule.evaluate(authentication, _request);

        expect(response, true);
      },
    );

    test(
      'permission >> user.create && (role >> User || role >> Admin)',
      () async {
        final rule =
            hasPermission('user.create') & (hasRole('User') | hasRole('Admin'));
        bool response = rule.evaluate(authentication, _request);

        expect(response, true);
      },
    );

    test(
      '(role >> Admin || role >> SuperUser) && permission >> user.edit',
      () async {
        final rule =
            (hasRole('Admin') | hasRole('SuperUser')) &
            hasPermission('user.edit');
        bool response = rule.evaluate(authentication, _request);

        expect(response, true);
      },
    );

    test('(role >> User && permission >> user.create) || (role >> Admin && permission >> user.delete)', () async {
      final rule =
          (hasRole('User') & hasPermission('user.create')) |
          (hasRole('Admin') & hasPermission('user.delete'));
      bool response = rule.evaluate(authentication, _request);

      expect(response, true);
    });

    test('Complex mismatch: (role >> Admin || role >> Guest) && permission >> user.create', () async {
      final rule =
          (hasRole('Admin') | hasRole('Guest')) & hasPermission('user.create');
      bool response = rule.evaluate(authentication, _request);

      expect(response, false);
    });

    test('Triple OR with success: role >> Admin || role >> User || role >> SuperUser', () async {
      final rule = hasRole('Admin') | hasRole('User') | hasRole('SuperUser');
      bool response = rule.evaluate(authentication, _request);

      expect(response, true);
    });

    test('Nested complex logic: (role >> User && (permission >> user.create || permission >> user.delete)) && role >> SuperUser', () async {
      final rule =
          (hasRole('User') &
              (hasPermission('user.create') | hasPermission('user.delete'))) &
          hasRole('SuperUser');
      bool response = rule.evaluate(authentication, _request);

      expect(response, true);
    });

    test('Multiple levels: ((role >> User && user.create) || (role >> Admin)) && role >> SuperUser', () async {
      final rule =
          (hasRole('User') & hasPermission('user.create')) |
          (hasRole('Admin') & hasRole('SuperUser'));
      bool response = rule.evaluate(authentication, _request);

      expect(response, true);
    });

    test('Anonymous user should fail rules', () async {
      final anonymous = Authentication.anonymous();

      expect(hasRole('User').evaluate(anonymous, _request), false);
      expect(hasPermission('user.create').evaluate(anonymous, _request), false);
      expect(
        (hasRole('User') | hasPermission('User')).evaluate(anonymous, _request),
        false,
      );
    });

    test('Authentication with no roles or permissions', () async {
      final emptyAuth = Authentication(principal: 'Empty');

      expect(hasRole('User').evaluate(emptyAuth, _request), false);
      expect(hasPermission('user.create').evaluate(emptyAuth, _request), false);
      expect(
        (hasRole('User') | hasPermission('User')).evaluate(emptyAuth, _request),
        false,
      );
    });

    test('Authority matches both roles and permissions', () async {
      expect(
        (hasRole('User') | hasPermission('User')).evaluate(
          authentication,
          _request,
        ),
        true,
      );
      expect(
        (hasRole('user.create') | hasPermission('user.create')).evaluate(
          authentication,
          _request,
        ),
        true,
      );
      expect(
        (hasRole('Admin') | hasPermission('Admin')).evaluate(
          authentication,
          _request,
        ),
        false,
      );
      expect(
        (hasRole('user.delete') | hasPermission('user.delete')).evaluate(
          authentication,
          _request,
        ),
        false,
      );
    });

    test('Complex mixed chaining: role >> User && (role >> Admin || permission >> user.edit)', () async {
      final rule =
          hasRole('User') & (hasRole('Admin') | hasPermission('user.edit'));
      expect(rule.evaluate(authentication, _request), true);
    });

    test('Deeply nested logic: ((A || B) && (C || D))', () async {
      // (Admin || User) && (user.delete || user.edit)
      final rule =
          (hasRole('Admin') | hasRole('User')) &
          (hasPermission('user.delete') | hasPermission('user.edit'));

      expect(rule.evaluate(authentication, _request), true);
    });

    test('Triple AND failure: role >> User && permission >> user.create && role >> Admin', () async {
      final rule =
          hasRole('User') & hasPermission('user.create') & hasRole('Admin');

      expect(rule.evaluate(authentication, _request), false);
    });

    test('Authority matching mixed set (roles and permissions)', () async {
      final rule =
          (hasRole('user.create') | hasPermission('user.create')) &
          (hasRole('SuperUser') | hasPermission('SuperUser'));
      expect(rule.evaluate(authentication, _request), true);
    });

    test('Rule logic with nested ORs and ANDs', () async {
      // (Admin OR (User AND user.edit))
      final rule =
          hasRole('Admin') | (hasRole('User') & hasPermission('user.edit'));
      expect(rule.evaluate(authentication, _request), true);

      // (Admin OR (User AND user.delete))
      final rule2 =
          hasRole('Admin') | (hasRole('User') & hasPermission('user.delete'));
      expect(rule2.evaluate(authentication, _request), false);
    });

    test('Case sensitivity', () async {
      expect(hasRole('user').evaluate(authentication, _request), false);
      expect(
        hasPermission('USER.CREATE').evaluate(authentication, _request),
        false,
      );
      expect(
        (hasRole('USER') | hasPermission('USER')).evaluate(
          authentication,
          _request,
        ),
        false,
      );
    });

    test('Mixing andd(), orr(), and() and or() in long chains', () async {
      // ((hasRole('User') AND hasPermission('user.edit')) OR hasRole('Admin')) AND (hasRole('SuperUser') | hasPermission('SuperUser'))
      final rule =
          hasRole('User') & hasPermission('user.edit') |
          hasRole('Admin') &
              (hasRole('SuperUser') | hasPermission('SuperUser'));

      expect(rule.evaluate(authentication, _request), true);

      // Change SuperUser to Guest (which authentication doesn't have)
      final ruleFail = rule & (hasRole('Guest') | hasPermission('Guest'));
      expect(ruleFail.evaluate(authentication, _request), false);
    });

    test('Chaining multiple orr() with authorities', () async {
      final rule =
          (hasRole('Admin') | hasPermission('Admin')) |
          (hasRole('Guest') | hasPermission('Guest')) |
          (hasRole('user.list') | hasPermission('user.list'));

      expect(rule.evaluate(authentication, _request), true);
    });

    test('Chaining multiple andd() with authorities', () async {
      final rule =
          (hasRole('User') | hasPermission('User')) &
          (hasRole('user.create') | hasPermission('user.create')) &
          (hasRole('user.edit') | hasPermission('user.edit'));

      expect(rule.evaluate(authentication, _request), true);
    });

    test('Complex nested structure with mixed builders', () async {
      // (User AND (create OR delete)) OR (Admin AND edit)
      final rule =
          hasRole('User') &
              (hasPermission('user.create') | hasPermission('user.delete')) |
          (hasRole('Admin') & hasPermission('user.edit'));

      expect(rule.evaluate(authentication, _request), true);
    });

    test('Redundant rules evaluation', () async {
      final rule = hasRole('User') & hasRole('User') | hasRole('User');
      expect(rule.evaluate(authentication, _request), true);
    });

    test('Deep nesting with multiple or() blocks', () async {
      final rule =
          hasRole('Guest') |
          (hasRole('Member') |
              (hasRole('User') & hasPermission('user.create')));
      expect(rule.evaluate(authentication, _request), true);
    });

    test('Sequential evaluation (left-to-right precedence check)', () async {
      // In this builder: A | B & C  => A || (B && C) due to Dart operator precedence
      // authentication has User and user.create
      // hasRole('Admin') || (hasRole('User') && hasPermission('user.create')) => false || (true && true) => true
      final rule1 =
          hasRole('Admin') | hasRole('User') & hasPermission('user.create');
      expect(rule1.evaluate(authentication, _request), true);

      // hasRole('Admin') || (hasRole('User') && hasPermission('user.delete'))
      // (false || (true && false)) => false
      final rule2 =
          hasRole('Admin') | hasRole('User') & hasPermission('user.delete');
      expect(rule2.evaluate(authentication, _request), false);
    });

    test(
      'Evaluate with different Authentication objects in same test',
      () async {
        final rule = hasRole('Admin') | hasPermission('sudo');

        final admin = Authentication(principal: 'admin', roles: {'Admin'});
        final superUser = Authentication(
          principal: 'root',
          permissions: {'sudo'},
        );
        final normal = Authentication(principal: 'joe', roles: {'User'});

        expect(rule.evaluate(admin, _request), true);
        expect(rule.evaluate(superUser, _request), true);
        expect(rule.evaluate(normal, _request), false);
      },
    );

    test('Rule toString representation', () {
      final rule =
          hasPermission('user.create') &
          (hasRole('User') & hasRole('SuperUser'));

      expect(
        rule.toString(),
        'hasPermission(user.create) && (hasRole(User) && hasRole(SuperUser))',
      );

      final rule2 =
          (hasRole('Admin') | hasRole('User')) & hasPermission('read');

      expect(
        rule2.toString(),
        '(hasRole(Admin) || hasRole(User)) && hasPermission(read)',
      );
    });
  });
}

/// The rules of these tests don't look at the request
final RequestEntity _request = RequestEntity(
  'GET',
  Uri.parse('http://localhost/'),
);
