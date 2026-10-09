import 'package:winter/winter.dart';

/// A rule as an [AuthFilter]: `hasRole('admin').toFilter()`
///
/// {@category Security}
extension AuthFilterFromRuleBuilder on RuleBuilder {
  /// An [AuthFilter] with this rule (and an authenticated user, unless [authenticated] is false)
  AuthFilter toFilter({bool authenticated = true}) =>
      AuthFilter(authenticated: authenticated, rules: this);
}

/// A rule as the [FilterConfig] of a route: `filterConfig: hasRole('admin').toFilterConfig()`
///
/// {@category Security}
extension FilterConfigFromRuleBuilder on RuleBuilder {
  /// A [FilterConfig] with the [AuthFilter] of this rule (see [AuthFilterFromRuleBuilder.toFilter])
  FilterConfig toFilterConfig({bool authenticated = true}) =>
      FilterConfig([toFilter(authenticated: authenticated)]);
}

/// The principal of the request in progress (read from the `RequestScope`, from any code), as a
/// [T]. A 401 ([UnauthorizedException]) when nobody is authenticated, so a handler behind an
/// `AuthFilter` needs no cast and no `!`. A principal of another type is a [StateError].
///
/// {@category Security}
T requestPrincipal<T>() =>
    _principalOf<T>(requestSecurityContext?.authentication) ??
    (throw _notAuthenticated);

/// Like [requestPrincipal], but null when nobody is authenticated (a public route)
///
/// {@category Security}
T? requestPrincipalOrNull<T>() =>
    _principalOf<T>(requestSecurityContext?.authentication);

/// The principal of a request, typed: `request.principal<User>()`
///
/// {@category Security}
extension RequestPrincipalX on RequestEntity {
  /// The principal of this request as a [T], see [requestPrincipal]
  T principal<T>() =>
      _principalOf<T>(securityContext.authentication) ??
      (throw _notAuthenticated);

  /// Like [principal], but null when nobody is authenticated
  T? principalOrNull<T>() => _principalOf<T>(securityContext.authentication);
}

UnauthorizedException get _notAuthenticated => const UnauthorizedException(
  headers: {HttpHeader.wwwAuthenticate: 'Bearer'},
);

T? _principalOf<T>(Authentication? authentication) {
  if (authentication == null || !authentication.authenticated) return null;
  final Object? principal = authentication.principal;
  if (principal is T) return principal;
  throw StateError(
    'The principal of the request is a ${principal.runtimeType}, not a $T',
  );
}
