import 'package:winter/winter.dart';

class AuthFilter extends Filter {
  final bool authenticated;
  final RuleBuilder? rules;
  final bool Function(RequestEntity)? _shouldFilter;

  AuthFilter({this.authenticated = true, this.rules, this._shouldFilter});

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final securityContext = request.securityContext;
    final bool isAuthenticated = securityContext.isAuthenticated;

    ///401: nobody (or an authentication with `authenticated: false`) is logged in
    if (authenticated && !isAuthenticated) {
      throw const UnauthorizedException();
    }

    if (rules != null) {
      final authentication =
          securityContext.authentication ?? Authentication.anonymous();
      if (!rules!.evaluate(authentication)) {
        ///An anonymous user may get access by logging in (401),
        ///a logged in user without the needed roles/permissions can't (403)
        throw isAuthenticated
            ? const ForbiddenException()
            : const UnauthorizedException();
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
