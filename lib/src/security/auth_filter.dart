import 'package:winter/winter.dart';

/// Lets a request go on only if it's authenticated ([authenticated]) and passes the [rules]:
/// otherwise a 401 (nobody authenticated) or a 403 (authenticated, but not allowed).
///
/// ```dart
/// Route.parent(
///   path: '/admin',
///   filterConfig: FilterConfig([AuthFilter(rules: hasRole('admin') | hasPermission('admin.read'))]),
///   routes: adminRoutes,
/// )
/// ```
///
/// It only checks: the authentication is set before it by a filter of the app (see
/// [RequestSecurityContext]).
///
/// {@category Security}
class AuthFilter extends Filter {
  /// Whether the request needs an authenticated user (a 401 without one)
  final bool authenticated;

  /// The rules the user must pass (a 403 otherwise), or null for none
  final RuleBuilder? rules;
  final bool Function(RequestEntity)? _shouldFilter;

  /// The `WWW-Authenticate` of a 401, required by RFC 9110: `Bearer` by default,
  /// `Basic realm="api"` for basic authentication
  final String challenge;

  /// The `Cache-Control` added to a response it lets through when the response has none:
  /// `private` by default (it depends on who asked, so a shared cache must never give it to
  /// someone else), another directive (`no-store`), or null to add nothing. Null fits a protocol
  /// whose responses carry only the `Cache-Control` the app stored (an S3 object), or a public
  /// resource a CDN should cache; a shared cache already never keeps the answer to a request with
  /// `Authorization` (RFC 9111 §3.5), so `private` matters most with a cookie session.
  final String? cacheControl;

  /// A filter that needs an authenticated user passing [rules]; the requests where
  /// `shouldFilter` returns false skip it
  AuthFilter({
    this.authenticated = true,
    this.rules,
    this._shouldFilter,
    this.challenge = 'Bearer',
    this.cacheControl = 'private',
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

    /// 401: nobody (or an authentication with `authenticated: false`) is logged in
    if (authenticated && !isAuthenticated) {
      throw _unauthorized;
    }

    if (rules != null) {
      final authentication =
          securityContext.authentication ?? Authentication.anonymous();
      if (!rules!.evaluate(authentication, request)) {
        /// An anonymous user may get access by logging in (401),
        /// a logged in user without the needed roles/permissions can't (403)
        throw isAuthenticated ? const ForbiddenException() : _unauthorized;
      }
    }

    final ResponseEntity response = await chain.doFilter(request);
    final String? directive = cacheControl;
    // It depends on who asked: a shared cache (a CDN, a proxy) must not give it to someone else
    return directive == null ||
            response.headersAll.containsKey(HttpHeader.cacheControl)
        ? response
        : response.copyWith(headers: {HttpHeader.cacheControl: directive});
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
