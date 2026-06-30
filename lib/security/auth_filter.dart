import 'package:winter/winter.dart';

class AuthFilter extends Filter {
  final bool authenticated;
  final RuleBuilder? rules;

  AuthFilter({this.authenticated = true, this.rules});

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final securityContext = request.securityContext;

    if (authenticated && !securityContext.isAuthenticated) {
      return ResponseEntity.unauthorized();
    }

    if (rules != null) {
      final authentication =
          securityContext.authentication ?? Authentication.anonymous();
      if (!rules!.evaluate(authentication)) {
        return ResponseEntity.forbidden();
      }
    }

    return chain.doFilter(request);
  }
}
