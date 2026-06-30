import 'package:winter/request_entity.dart';

class RequestSecurityContext<T> {
  Authentication<T>? _authentication;

  RequestSecurityContext.empty();

  void clearContext() {
    _authentication = null;
  }

  bool get isAuthenticated =>
      _authentication != null && _authentication!.authenticated == true;

  Authentication<T>? get authentication => _authentication;

  void setAuthentication(Authentication<T>? authentication) {
    _authentication = authentication;
  }
}

class Authentication<T> {
  final T principal;
  final Set<String> roles;
  final Set<String> permissions;

  final bool authenticated;

  Authentication({
    required this.principal,
    this.authenticated = true,
    Set<String>? roles,
    Set<String>? permissions,
  }) : roles = Set.unmodifiable(roles ?? {}),
       permissions = Set.unmodifiable(permissions ?? {});

  static Authentication anonymous() => Authentication(
    principal: 'Anonymous',
    roles: {},
    permissions: {},
    authenticated: false,
  );

  String get name => principal.toString();

  Set<String> get authorities => Set.unmodifiable([...roles, ...permissions]);

  Authentication<T> copyWith({
    T? principal,
    bool? authenticated,
    Set<String>? roles,
    Set<String>? permissions,
  }) {
    return Authentication<T>(
      principal: principal ?? this.principal,
      authenticated: authenticated ?? this.authenticated,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
    );
  }
}

extension RequestSecurityContextX on RequestEntity {
  static const String _securityContextKey = 'winter.context.security';

  RequestSecurityContext get securityContext {
    RequestSecurityContext? currentContext =
        context[_securityContextKey] as RequestSecurityContext?;
    if (currentContext != null) {
      return currentContext;
    } else {
      RequestSecurityContext newContext = RequestSecurityContext.empty();
      context[_securityContextKey] = newContext;

      return context[_securityContextKey] as RequestSecurityContext;
    }
  }
}
