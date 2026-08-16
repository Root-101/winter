import 'package:winter/winter.dart';

class AuthFilter extends Filter {
  final bool authenticated;
  final RuleBuilder? rules;
  final bool Function(RequestEntity)? _shouldFilter;

  AuthFilter({this.authenticated = true, this.rules, this._shouldFilter});

  @override
  Future<ResponseEntity> doFilter(RequestEntity request,
      FilterChain chain,) async {
    final securityContext = request.securityContext;

    if (authenticated && !securityContext.isAuthenticated) {
      if (securityContext.authentication == null) {
        return build401(request);
      }
      return build403(request);
    }

    if (rules != null) {
      final authentication =
          securityContext.authentication ?? Authentication.anonymous();
      if (!rules!.evaluate(authentication)) {
        return build403(request);
      }
    }

    return chain.doFilter(request);
  }

  ResponseEntity build401(RequestEntity request) {
    return ResponseEntity.unauthorized();
  }

  ResponseEntity build403(RequestEntity request) {
    return ResponseEntity.forbidden();
  }

  @override
  bool shouldFilter(RequestEntity request) {
    return _shouldFilter?.call(request) ?? super.shouldFilter(request);
  }

  @override
  String toString() {
    return 'AuthFilter{authenticated: $authenticated, rules: $rules, shouldFilter: ${_shouldFilter !=
        null ? 'custom' : 'all'}}';
  }
}
