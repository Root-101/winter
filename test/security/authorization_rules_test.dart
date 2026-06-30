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
      final rule = hasAuthority('User');
      bool response = rule.evaluate(authentication);

      expect(response, true);
    });

    test('authority >> user.create', () async {
      final rule = hasAuthority('user.create');
      bool response = rule.evaluate(authentication);

      expect(response, true);
    });

    test('role >> User', () async {
      final rule = hasRole('User');
      bool response = rule.evaluate(authentication);

      expect(response, true);
    });

    test('role >> Admin', () async {
      final rule = hasRole('Admin');
      bool response = rule.evaluate(authentication);

      expect(response, false);
    });

    test('permission >> user.create', () async {
      final rule = hasPermission('user.create');
      bool response = rule.evaluate(authentication);

      expect(response, true);
    });

    test('permission >> user.delete', () async {
      final rule = hasPermission('user.delete');
      bool response = rule.evaluate(authentication);

      expect(response, false);
    });

    test('permission >> User', () async {
      final rule = hasPermission('User');
      bool response = rule.evaluate(authentication);

      expect(response, false);
    });

    test('role >> user.create', () async {
      final rule = hasRole('user.create');
      bool response = rule.evaluate(authentication);

      expect(response, false);
    });

    test(
      'permission >> user.create && permission >> user.edit && role >> User',
      () async {
        final rule = hasPermission(
          'user.create',
        ).andd().hasPermission('user.edit').andd().hasRole('User');
        bool response = rule.evaluate(authentication);

        expect(response, true);
      },
    );

    test(
      'permission >> user.create && (role >> User && role >> SuperUser)',
      () async {
        final rule = hasPermission(
          'user.create',
        ).and(hasRole('User').andd().hasRole('SuperUser'));
        bool response = rule.evaluate(authentication);

        expect(response, true);
      },
    );

    test(
      'permission >> user.create && (role >> User || role >> Admin)',
      () async {
        final rule = hasPermission(
          'user.create',
        ).and(hasRole('User').orr().hasRole('Admin'));
        bool response = rule.evaluate(authentication);

        expect(response, true);
      },
    );

    test(
      '(role >> Admin || role >> SuperUser) && permission >> user.edit',
      () async {
        final rule = (hasRole(
          'Admin',
        ).orr().hasRole('SuperUser')).andd().hasPermission('user.edit');
        bool response = rule.evaluate(authentication);

        expect(response, true);
      },
    );

    test(
      '(role >> User && permission >> user.create) || (role >> Admin && permission >> user.delete)',
      () async {
        final rule = (hasRole('User').andd().hasPermission(
          'user.create',
        )).or(hasRole('Admin').andd().hasPermission('user.delete'));
        bool response = rule.evaluate(authentication);

        expect(response, true);
      },
    );

    test(
      'Complex mismatch: (role >> Admin || role >> Guest) && permission >> user.create',
      () async {
        final rule = (hasRole(
          'Admin',
        ).orr().hasRole('Guest')).andd().hasPermission('user.create');
        bool response = rule.evaluate(authentication);

        expect(response, false);
      },
    );

    test(
      'Triple OR with success: role >> Admin || role >> User || role >> SuperUser',
      () async {
        final rule = hasRole(
          'Admin',
        ).orr().hasRole('User').orr().hasRole('SuperUser');
        bool response = rule.evaluate(authentication);

        expect(response, true);
      },
    );

    test(
      'Nested complex logic: (role >> User && (permission >> user.create || permission >> user.delete)) && role >> SuperUser',
      () async {
        final rule = (hasRole('User').and(
          hasPermission('user.create').orr().hasPermission('user.delete'),
        )).andd().hasRole('SuperUser');
        bool response = rule.evaluate(authentication);

        expect(response, true);
      },
    );

    test(
      'Multiple levels: ((role >> User && user.create) || (role >> Admin)) && role >> SuperUser',
      () async {
        final rule = (hasRole('User').andd().hasPermission(
          'user.create',
        )).or(hasRole('Admin')).andd().hasRole('SuperUser');
        bool response = rule.evaluate(authentication);

        expect(response, true);
      },
    );

    test('Anonymous user should fail rules', () async {
      final anonymous = Authentication.anonymous();

      expect(hasRole('User').evaluate(anonymous), false);
      expect(hasPermission('user.create').evaluate(anonymous), false);
      expect(hasAuthority('User').evaluate(anonymous), false);
    });

    test('Authentication with no roles or permissions', () async {
      final emptyAuth = Authentication(principal: 'Empty');

      expect(hasRole('User').evaluate(emptyAuth), false);
      expect(hasPermission('user.create').evaluate(emptyAuth), false);
      expect(hasAuthority('User').evaluate(emptyAuth), false);
    });

    test('Authority matches both roles and permissions', () async {
      expect(hasAuthority('User').evaluate(authentication), true);
      expect(hasAuthority('user.create').evaluate(authentication), true);
      expect(hasAuthority('Admin').evaluate(authentication), false);
      expect(hasAuthority('user.delete').evaluate(authentication), false);
    });

    test(
      'Complex mixed chaining: role >> User && (role >> Admin || permission >> user.edit)',
      () async {
        final rule = hasRole(
          'User',
        ).and(hasRole('Admin').orr().hasPermission('user.edit'));
        expect(rule.evaluate(authentication), true);
      },
    );

    test('Deeply nested logic: ((A || B) && (C || D))', () async {
      // (Admin || User) && (user.delete || user.edit)
      final rule = (hasRole('Admin').orr().hasRole(
        'User',
      )).and(hasPermission('user.delete').orr().hasPermission('user.edit'));

      expect(rule.evaluate(authentication), true);
    });

    test(
      'Triple AND failure: role >> User && permission >> user.create && role >> Admin',
      () async {
        final rule = hasRole(
          'User',
        ).andd().hasPermission('user.create').andd().hasRole('Admin');

        expect(rule.evaluate(authentication), false);
      },
    );

    test('Authority matching mixed set (roles and permissions)', () async {
      final rule = hasAuthority('user.create').andd().hasAuthority('SuperUser');
      expect(rule.evaluate(authentication), true);
    });

    test('Rule logic with nested ORs and ANDs', () async {
      // (Admin OR (User AND user.edit))
      final rule = hasRole(
        'Admin',
      ).or(hasRole('User').andd().hasPermission('user.edit'));
      expect(rule.evaluate(authentication), true);

      // (Admin OR (User AND user.delete))
      final rule2 = hasRole(
        'Admin',
      ).or(hasRole('User').andd().hasPermission('user.delete'));
      expect(rule2.evaluate(authentication), false);
    });

    test('Case sensitivity', () async {
      expect(hasRole('user').evaluate(authentication), false);
      expect(hasPermission('USER.CREATE').evaluate(authentication), false);
      expect(hasAuthority('USER').evaluate(authentication), false);
    });

    test('Mixing andd(), orr(), and() and or() in long chains', () async {
      // ((hasRole('User') AND hasPermission('user.edit')) OR hasRole('Admin')) AND hasAuthority('SuperUser')
      final rule = hasRole('User')
          .andd()
          .hasPermission('user.edit')
          .or(hasRole('Admin'))
          .andd()
          .hasAuthority('SuperUser');

      expect(rule.evaluate(authentication), true);

      // Change SuperUser to Guest (which authentication doesn't have)
      final ruleFail = rule.andd().hasAuthority('Guest');
      expect(ruleFail.evaluate(authentication), false);
    });

    test('Chaining multiple orr() with authorities', () async {
      final rule = hasAuthority('Admin')
          .orr()
          .hasAuthority('Guest')
          .orr()
          .hasAuthority('user.list');

      expect(rule.evaluate(authentication), true);
    });

    test('Chaining multiple andd() with authorities', () async {
      final rule = hasAuthority('User')
          .andd()
          .hasAuthority('user.create')
          .andd()
          .hasAuthority('user.edit');

      expect(rule.evaluate(authentication), true);
    });

    test('Complex nested structure with mixed builders', () async {
      // (User AND (create OR delete)) OR (Admin AND edit)
      final rule = hasRole('User')
          .and(hasPermission('user.create').orr().hasPermission('user.delete'))
          .or(hasRole('Admin').andd().hasPermission('user.edit'));

      expect(rule.evaluate(authentication), true);
    });

    test('Redundant rules evaluation', () async {
      final rule = hasRole('User').andd().hasRole('User').orr().hasRole('User');
      expect(rule.evaluate(authentication), true);
    });

    test('Deep nesting with multiple or() blocks', () async {
      final rule = hasRole('Guest').or(
        hasRole('Member').or(
          hasRole('User').andd().hasPermission('user.create'),
        ),
      );
      expect(rule.evaluate(authentication), true);
    });

    test('Sequential evaluation (left-to-right precedence check)', () async {
      // In this builder: A.orr().B.andd().C  => (A || B) && C
      // authentication has User and user.create
      // (hasRole('Admin') || hasRole('User')) && hasPermission('user.create') => (false || true) && true => true
      final rule1 = hasRole('Admin')
          .orr()
          .hasRole('User')
          .andd()
          .hasPermission('user.create');
      expect(rule1.evaluate(authentication), true);

      // hasRole('Admin') || (hasRole('User') && hasPermission('user.delete'))
      // (false || (true && false)) => false
      final rule2 = hasRole('Admin')
          .orr()
          .hasRole('User')
          .andd()
          .hasPermission('user.delete');
      expect(rule2.evaluate(authentication), false);
    });

    test('Evaluate with different Authentication objects in same test', () async {
      final rule = hasRole('Admin').orr().hasPermission('sudo');

      final admin = Authentication(principal: 'admin', roles: {'Admin'});
      final superUser = Authentication(principal: 'root', permissions: {'sudo'});
      final normal = Authentication(principal: 'joe', roles: {'User'});

      expect(rule.evaluate(admin), true);
      expect(rule.evaluate(superUser), true);
      expect(rule.evaluate(normal), false);
    });
  });
}
