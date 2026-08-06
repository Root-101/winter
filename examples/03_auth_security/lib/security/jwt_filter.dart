import 'package:auth_security_example/auth_security_example.dart';

class JwtFilter extends Filter {
  final JwtService jwtService;

  JwtFilter(this.jwtService);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final authHeader = request.headers[HttpHeaders.authorization];

    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      final token = authHeader.substring(7);
      final payload = jwtService.verifyToken(token);

      if (payload != null) {
        request.securityContext.setAuthentication(
          Authentication(
            principal: payload['sub'],
            roles: Set.from(payload['roles'] ?? []),
            permissions: Set.from(payload['permissions'] ?? []),
          ),
        );
      }
    } else {
      request.securityContext.clearContext();
    }

    return chain.doFilter(request);
  }
}
