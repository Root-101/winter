import 'package:winter/winter.dart';

/// Who makes a request: its [authentication], set by a filter of the app and read by
/// [AuthFilter], the handlers and any code of the request (`requestAuthentication`).
///
/// ```dart
/// request.securityContext.setAuthentication(
///   Authentication(principal: user, roles: {'admin'}),
/// );
/// ```
///
/// {@category Security}
class RequestSecurityContext<T> {
  Authentication<T>? _authentication;

  /// A context without authentication: the server creates one per request
  RequestSecurityContext.empty();

  /// Removes the authentication
  void clear() {
    _authentication = null;
  }

  /// Whether there is an authentication, and it's [Authentication.authenticated]
  bool get isAuthenticated =>
      _authentication != null && _authentication!.authenticated == true;

  /// The authentication of the request, or null
  Authentication<T>? get authentication => _authentication;

  /// Sets (or, with null, removes) the authentication of the request
  void setAuthentication(Authentication<T>? authentication) {
    _authentication = authentication;
  }
}

/// Who is authenticated: the [principal] (the user of the app) and what it may do. Its [roles]
/// and [permissions] are checked by the rules of [AuthFilter] (`hasRole`, `hasPermission`).
///
/// {@category Security}
class Authentication<T> {
  /// The user, of the type of the app; read it with `request.principal<T>()`
  final T principal;

  /// The roles (`admin`). Read-only.
  final Set<String> roles;

  /// The permissions (`users.read`). Read-only.
  final Set<String> permissions;

  /// False for an anonymous user: [AuthFilter] answers it with a 401
  final bool authenticated;

  /// The authentication of [principal]
  Authentication({
    required this.principal,
    this.authenticated = true,
    Set<String>? roles,
    Set<String>? permissions,
  }) : roles = Set.unmodifiable(roles ?? {}),
       permissions = Set.unmodifiable(permissions ?? {});

  /// Nobody: not [authenticated], without roles nor permissions
  static Authentication anonymous() => Authentication(
    principal: 'Anonymous',
    roles: {},
    permissions: {},
    authenticated: false,
  );

  /// The [principal] as text
  String get name => principal.toString();

  /// A copy with the values given
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
///
/// {@category Security}
extension RequestSecurityContextX on RequestEntity {
  /// Security context of this request, created the first time.
  /// The server creates it before the filters, so the copies of the request share it.
  RequestSecurityContext get securityContext => context.putIfAbsent(
    _securityContextKey,
    RequestSecurityContext<dynamic>.empty,
  );
}
