import 'package:winter/winter.dart';

/// The authenticated user has the [role]
///
/// {@category Security}
RuleBuilder hasRole(String role) => RuleBuilder(RoleRule(role));

/// The authenticated user has the [permission]
///
/// {@category Security}
RuleBuilder hasPermission(String permission) =>
    RuleBuilder(PermissionRule(permission));

/// A rule of the app, that can use the request (ex: only the owner of a resource):
///
/// ```dart
/// AuthFilter(
///   rules: hasRole('admin') |
///       rule((auth, request) => request.pathParams['id'] == auth.name, describe: 'isOwner'),
/// )
/// ```
///
/// [describe] is how it's shown in logs and `toString`.
///
/// {@category Security}
RuleBuilder rule(
  bool Function(Authentication authentication, RequestEntity request) check, {
  String describe = 'rule',
}) => RuleBuilder(_FunctionRule(check, describe));

/// Whether a request can go on, from its [Authentication]. Combine them with `&` and `|`
/// (see [RuleBuilder]), and write your own by extending this class.
///
/// {@category Security}
abstract class AuthorizationRule {
  /// A rule (const, so a rule of the app can be a constant)
  const AuthorizationRule();

  /// Whether [authentication] may make [request]
  bool evaluate(Authentication authentication, RequestEntity request);

  /// A readable form of the rule, for logs and `toString` (`hasRole(admin)`).
  /// By default the name of its class.
  String describe() => '$runtimeType';

  @override
  String toString() => describe();
}

/// The authenticated user has [role] (built by [hasRole])
///
/// {@category Security}
class RoleRule extends AuthorizationRule {
  /// The role required
  final String role;

  /// The rule of [role]
  const RoleRule(this.role);

  @override
  bool evaluate(Authentication authentication, RequestEntity request) =>
      authentication.roles.contains(role);

  @override
  String describe() => 'hasRole($role)';
}

/// The authenticated user has [permission] (built by [hasPermission])
///
/// {@category Security}
class PermissionRule extends AuthorizationRule {
  /// The permission required
  final String permission;

  /// The rule of [permission]
  const PermissionRule(this.permission);

  @override
  bool evaluate(Authentication authentication, RequestEntity request) =>
      authentication.permissions.contains(permission);

  @override
  String describe() => 'hasPermission($permission)';
}

/// Both rules pass (`a & b`)
///
/// {@category Security}
class AndRule extends AuthorizationRule {
  /// The first rule, evaluated first
  final AuthorizationRule left;

  /// The second rule
  final AuthorizationRule right;

  /// [left] & [right]
  const AndRule(this.left, this.right);

  @override
  bool evaluate(Authentication authentication, RequestEntity request) =>
      left.evaluate(authentication, request) &&
      right.evaluate(authentication, request);

  @override
  String describe() => '(${left.describe()} && ${right.describe()})';
}

/// One of the rules passes (`a | b`): [right] is only evaluated if [left] fails
///
/// {@category Security}
class OrRule extends AuthorizationRule {
  /// The first rule, evaluated first
  final AuthorizationRule left;

  /// The second rule
  final AuthorizationRule right;

  /// [left] | [right]
  const OrRule(this.left, this.right);

  @override
  bool evaluate(Authentication authentication, RequestEntity request) =>
      left.evaluate(authentication, request) ||
      right.evaluate(authentication, request);

  @override
  String describe() => '(${left.describe()} || ${right.describe()})';
}

class _FunctionRule extends AuthorizationRule {
  final bool Function(Authentication authentication, RequestEntity request)
  _check;
  final String _description;

  const _FunctionRule(this._check, this._description);

  @override
  bool evaluate(Authentication authentication, RequestEntity request) =>
      _check(authentication, request);

  @override
  String describe() => _description;
}

/// A rule that combines with others: `hasRole('admin') | hasPermission('users.read')`
///
/// {@category Security}
class RuleBuilder extends AuthorizationRule {
  final AuthorizationRule _rule;

  /// Wraps a rule so it can be combined; [hasRole], [hasPermission] and [rule] build one
  RuleBuilder(this._rule);

  @override
  bool evaluate(Authentication authentication, RequestEntity request) =>
      _rule.evaluate(authentication, request);

  @override
  String describe() => _rule.describe();

  @override
  String toString() {
    final res = describe();
    if (res.startsWith('(') && res.endsWith(')')) {
      return res.substring(1, res.length - 1);
    }
    return res;
  }

  /// This rule and [other] must pass
  RuleBuilder operator &(AuthorizationRule other) {
    return RuleBuilder(AndRule(_rule, other));
  }

  /// This rule or [other] must pass
  RuleBuilder operator |(AuthorizationRule other) {
    return RuleBuilder(OrRule(_rule, other));
  }
}
