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
}

class RoleRule extends AuthorizationRule {
  final String role;

  const RoleRule(this.role);

  @override
  bool evaluate(Authentication authentication) {
    return authentication.roles.contains(role);
  }
}

class PermissionRule extends AuthorizationRule {
  final String permission;

  const PermissionRule(this.permission);

  @override
  bool evaluate(Authentication authentication) {
    return authentication.permissions.contains(permission);
  }
}

class AuthorityRule extends AuthorizationRule {
  final String authority;

  const AuthorityRule(this.authority);

  @override
  bool evaluate(Authentication authentication) {
    return authentication.authorities.contains(authority);
  }
}

class AndRule extends AuthorizationRule {
  final AuthorizationRule left;
  final AuthorizationRule right;

  const AndRule(this.left, this.right);

  @override
  bool evaluate(Authentication authentication) {
    return left.evaluate(authentication) && right.evaluate(authentication);
  }
}

class OrRule extends AuthorizationRule {
  final AuthorizationRule left;
  final AuthorizationRule right;

  const OrRule(this.left, this.right);

  @override
  bool evaluate(Authentication authentication) {
    return left.evaluate(authentication) || right.evaluate(authentication);
  }
}

class RuleBuilder extends AuthorizationRule {
  AuthorizationRule _rule;

  RuleBuilder(this._rule);

  @override
  bool evaluate(authentication) => _rule.evaluate(authentication);

  RuleBuilder and(AuthorizationRule other) {
    _rule = AndRule(_rule, other);
    return this;
  }

  RuleBuilder or(AuthorizationRule other) {
    _rule = OrRule(_rule, other);
    return this;
  }

  PendingAnd andd() => PendingAnd(this);

  PendingOr orr() => PendingOr(this);

  void _appendAnd(AuthorizationRule rule) {
    _rule = AndRule(_rule, rule);
  }

  void _appendOr(AuthorizationRule rule) {
    _rule = OrRule(_rule, rule);
  }
}

class PendingAnd {
  final RuleBuilder builder;

  PendingAnd(this.builder);

  RuleBuilder hasRole(String role) {
    builder._appendAnd(RoleRule(role));
    return builder;
  }

  RuleBuilder hasPermission(String permission) {
    builder._appendAnd(PermissionRule(permission));
    return builder;
  }

  RuleBuilder hasAuthority(String authority) {
    builder._appendAnd(AuthorityRule(authority));
    return builder;
  }
}

class PendingOr {
  final RuleBuilder builder;

  PendingOr(this.builder);

  RuleBuilder hasRole(String role) {
    builder._appendOr(RoleRule(role));
    return builder;
  }

  RuleBuilder hasPermission(String permission) {
    builder._appendOr(PermissionRule(permission));
    return builder;
  }

  RuleBuilder hasAuthority(String authority) {
    builder._appendOr(AuthorityRule(authority));
    return builder;
  }
}
