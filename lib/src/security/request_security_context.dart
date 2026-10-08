import 'package:winter/winter.dart';

class RequestSecurityContext<T> {
  Authentication<T>? _authentication;

  RequestSecurityContext.empty();

  void clear() {
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

/// The key of the security context in the [ContextMap] of a request
final ContextKey<RequestSecurityContext> _securityContextKey =
    ContextKey<RequestSecurityContext>('winter.security');

/// The security of a request: a value of its context, found by a typed key. The same pattern
/// extends a request with data of the app (see [ContextMap]).
extension RequestSecurityContextX on RequestEntity {
  /// Security context of this request, created the first time.
  /// The server creates it before the filters, so the copies of the request share it.
  RequestSecurityContext get securityContext => context.putIfAbsent(
    _securityContextKey,
    RequestSecurityContext<dynamic>.empty,
  );
}
