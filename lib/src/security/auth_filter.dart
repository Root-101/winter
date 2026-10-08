import 'package:winter/winter.dart';

/// Lets a request go on only if it's authenticated ([authenticated]) and passes the [rules]:
/// otherwise a 401 (nobody authenticated) or a 403 (authenticated, but not allowed).
class AuthFilter extends Filter {
  final bool authenticated;
  final RuleBuilder? rules;
  final bool Function(RequestEntity)? _shouldFilter;

  /// The `WWW-Authenticate` of a 401, required by RFC 9110: `Bearer` by default,
  /// `Basic realm="api"` for basic authentication
  final String challenge;

  AuthFilter({
    this.authenticated = true,
    this.rules,
    this._shouldFilter,
    this.challenge = 'Bearer',
  });

  UnauthorizedException get _unauthorized =>
      UnauthorizedException(headers: {HttpHeader.wwwAuthenticate: challenge});

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final securityContext = request.securityContext;
    final bool isAuthenticated = securityContext.isAuthenticated;

    ///401: nobody (or an authentication with `authenticated: false`) is logged in
    if (authenticated && !isAuthenticated) {
      throw _unauthorized;
    }

    if (rules != null) {
      final authentication =
          securityContext.authentication ?? Authentication.anonymous();
      if (!rules!.evaluate(authentication, request)) {
        ///An anonymous user may get access by logging in (401),
        ///a logged in user without the needed roles/permissions can't (403)
        throw isAuthenticated ? const ForbiddenException() : _unauthorized;
      }
    }

    return chain.doFilter(request);
  }

  @override
  bool shouldFilter(RequestEntity request) {
    return _shouldFilter?.call(request) ?? super.shouldFilter(request);
  }

  @override
  String toString() {
    return 'AuthFilter{authenticated: $authenticated, rules: $rules, shouldFilter: ${_shouldFilter != null ? 'custom' : 'all'}}';
  }
}
