import 'package:winter/winter.dart';

RuleBuilder hasRole(String role) {
  return RuleBuilder(RoleRule(role));
}

RuleBuilder hasPermission(String permission) {
  return RuleBuilder(PermissionRule(permission));
}

RuleBuilder hasAuthority(String authority) {
  return RuleBuilder(AuthorityRule(authority));
}

abstract class AuthorizationRule {
  const AuthorizationRule();

  bool evaluate(Authentication authentication);

  String _toExpression();

  @override
  String toString() => _toExpression();
}

class RoleRule extends AuthorizationRule {
  final String role;

  const RoleRule(this.role);

  @override
  bool evaluate(Authentication authentication) {
    return authentication.roles.contains(role);
  }

  @override
  String _toExpression() => 'hasRole($role)';
}

class PermissionRule extends AuthorizationRule {
  final String permission;

  const PermissionRule(this.permission);

  @override
  bool evaluate(Authentication authentication) {
    return authentication.permissions.contains(permission);
  }

  @override
  String _toExpression() => 'hasPermission($permission)';
}

class AuthorityRule extends AuthorizationRule {
  final String authority;

  const AuthorityRule(this.authority);

  @override
  bool evaluate(Authentication authentication) {
    return authentication.authorities.contains(authority);
  }

  @override
  String _toExpression() => 'hasAuthority($authority)';
}

class AndRule extends AuthorizationRule {
  final AuthorizationRule left;
  final AuthorizationRule right;

  const AndRule(this.left, this.right);

  @override
  bool evaluate(Authentication authentication) {
    return left.evaluate(authentication) && right.evaluate(authentication);
  }

  @override
  String _toExpression() =>
      '(${left._toExpression()} && ${right._toExpression()})';
}

class OrRule extends AuthorizationRule {
  final AuthorizationRule left;
  final AuthorizationRule right;

  const OrRule(this.left, this.right);

  @override
  bool evaluate(Authentication authentication) {
    return left.evaluate(authentication) || right.evaluate(authentication);
  }

  @override
  String _toExpression() =>
      '(${left._toExpression()} || ${right._toExpression()})';
}

class RuleBuilder extends AuthorizationRule {
  final AuthorizationRule _rule;

  RuleBuilder(this._rule);

  @override
  bool evaluate(authentication) => _rule.evaluate(authentication);

  @override
  String _toExpression() => _rule._toExpression();

  @override
  String toString() {
    final res = _toExpression();
    if (res.startsWith('(') && res.endsWith(')')) {
      return res.substring(1, res.length - 1);
    }
    return res;
  }

  RuleBuilder operator &(AuthorizationRule other) {
    return RuleBuilder(AndRule(_rule, other));
  }

  RuleBuilder operator |(AuthorizationRule other) {
    return RuleBuilder(OrRule(_rule, other));
  }
}
