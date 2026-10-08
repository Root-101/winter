import 'package:winter/winter.dart';

extension AuthFilterFromRuleBuilder on RuleBuilder {
  AuthFilter toFilter({bool authenticated = true}) =>
      AuthFilter(authenticated: authenticated, rules: this);
}

extension FilterConfigFromRuleBuilder on RuleBuilder {
  FilterConfig toFilterConfig({bool authenticated = true}) =>
      FilterConfig([toFilter(authenticated: authenticated)]);
}

/// The principal of the request in progress (read from the `RequestScope`, from any code), as a
/// [T]. A 401 ([UnauthorizedException]) when nobody is authenticated, so a handler behind an
/// `AuthFilter` needs no cast and no `!`. A principal of another type is a [StateError].
T requestPrincipal<T>() =>
    _principalOf<T>(requestSecurityContext?.authentication) ??
    (throw _notAuthenticated);

/// Like [requestPrincipal], but null when nobody is authenticated (a public route)
T? requestPrincipalOrNull<T>() =>
    _principalOf<T>(requestSecurityContext?.authentication);

extension RequestPrincipalX on RequestEntity {
  /// The principal of this request as a [T], see [requestPrincipal]
  T principal<T>() =>
      _principalOf<T>(securityContext.authentication) ??
      (throw _notAuthenticated);

  /// Like [principal], but null when nobody is authenticated
  T? principalOrNull<T>() => _principalOf<T>(securityContext.authentication);
}

UnauthorizedException get _notAuthenticated =>
    UnauthorizedException(headers: {HttpHeader.wwwAuthenticate: 'Bearer'});

T? _principalOf<T>(Authentication? authentication) {
  if (authentication == null || !authentication.authenticated) return null;
  final Object? principal = authentication.principal;
  if (principal is T) return principal;
  throw StateError(
    'The principal of the request is a ${principal.runtimeType}, not a $T',
  );
}
