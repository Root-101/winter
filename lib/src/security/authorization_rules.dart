import 'package:winter/winter.dart';

/// The authenticated user has the [role]
///
/// {@category Security}
AuthorizationRule hasRole(String role) => _RoleRule(role);

/// The authenticated user has the [permission]
///
/// {@category Security}
AuthorizationRule hasPermission(String permission) =>
    _PermissionRule(permission);

/// A rule of the app, that can use the request (ex: only the owner of a resource):
///
/// ```dart
/// AuthFilter(
///   rule: hasRole('admin') |
///       rule((auth, request) => request.pathParams['id'] == auth.name, describe: 'isOwner'),
/// )
/// ```
///
/// [describe] is how it's shown in logs and `toString`.
///
/// {@category Security}
AuthorizationRule rule(
  bool Function(Authentication authentication, RequestEntity request) check, {
  String describe = 'rule',
}) => _FunctionRule(check, describe);

/// Whether a request can go on, from its [Authentication]. Combine them with `&` and `|`
/// (`hasRole('admin') | hasPermission('users.read')`), and write your own by extending this
/// class: it combines with the others as it is.
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

  /// This rule and [other] must pass ([other] is only evaluated if this one passes)
  AuthorizationRule operator &(AuthorizationRule other) =>
      _AndRule(this, other);

  /// This rule or [other] must pass ([other] is only evaluated if this one fails)
  AuthorizationRule operator |(AuthorizationRule other) => _OrRule(this, other);

  @override
  String toString() => describe();
}

class _RoleRule extends AuthorizationRule {
  final String role;

  const _RoleRule(this.role);

  @override
  bool evaluate(Authentication authentication, RequestEntity request) =>
      authentication.roles.contains(role);

  @override
  String describe() => 'hasRole($role)';
}

class _PermissionRule extends AuthorizationRule {
  final String permission;

  const _PermissionRule(this.permission);

  @override
  bool evaluate(Authentication authentication, RequestEntity request) =>
      authentication.permissions.contains(permission);

  @override
  String describe() => 'hasPermission($permission)';
}

/// Both rules pass (`a & b`): [right] is only evaluated if [left] passes
class _AndRule extends AuthorizationRule {
  final AuthorizationRule left;
  final AuthorizationRule right;

  const _AndRule(this.left, this.right);

  @override
  bool evaluate(Authentication authentication, RequestEntity request) =>
      left.evaluate(authentication, request) &&
      right.evaluate(authentication, request);

  @override
  String describe() => '(${left.describe()} && ${right.describe()})';

  @override
  String toString() => '${left.describe()} && ${right.describe()}';
}

/// One of the rules passes (`a | b`): [right] is only evaluated if [left] fails
class _OrRule extends AuthorizationRule {
  final AuthorizationRule left;
  final AuthorizationRule right;

  const _OrRule(this.left, this.right);

  @override
  bool evaluate(Authentication authentication, RequestEntity request) =>
      left.evaluate(authentication, request) ||
      right.evaluate(authentication, request);

  @override
  String describe() => '(${left.describe()} || ${right.describe()})';

  @override
  String toString() => '${left.describe()} || ${right.describe()}';
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
