import 'package:winter/winter.dart';

/// The security of the server: CORS and the security headers of every response.
/// Users can extend this class to customize them.
class SecurityConfig {
  final CorsConfig? _cors;

  /// The security headers added to every response (see [SecurityHeaders]), or null for none
  /// beyond the basic ones (`X-Content-Type-Options` and `X-Frame-Options`, always there)
  final SecurityHeaders? securityHeaders;

  SecurityConfig({this._cors, this.securityHeaders});

  /// Returns the CORS configuration.
  /// If it returns null, [CorsFilter] will not be automatically applied.
  CorsConfig? cors() => _cors;
}

/// Configuration for Cross-Origin Resource Sharing (CORS).
///
/// With [allowCredentials], list the [allowedOrigins]: with `'*'`, the origin of every request is
/// echoed (a browser rejects `'*'` with credentials), so any website can read the API with the
/// cookies of its user. Winter logs a warning when the server is built with that.
class CorsConfig {
  final List<String> allowedOrigins;
  final List<String> allowedMethods;
  final List<String> allowedHeaders;

  /// Headers a browser lets the client read, besides `X-Request-Id` (always exposed)
  final List<String> exposedHeaders;
  final bool allowCredentials;
  final int? maxAge;

  const CorsConfig({
    this.allowedOrigins = const ['*'],
    this.allowedMethods = const [
      'GET',
      'QUERY',
      'POST',
      'PUT',
      'DELETE',
      'OPTIONS',
      'PATCH',
    ],
    this.allowedHeaders = const ['*'],
    this.exposedHeaders = const [],
    this.allowCredentials = false,
    this.maxAge,
  });
}

/// Security headers for an API, added to every response by [SecurityConfig.securityHeaders]
/// (a header the response already has is kept):
///
/// ```dart
/// SecurityConfig(securityHeaders: const SecurityHeaders(hsts: true)) // served over HTTPS
/// ```
///
/// `X-Content-Type-Options: nosniff` and `X-Frame-Options: DENY` are always there, with or without
/// this configuration.
class SecurityHeaders {
  /// `Referrer-Policy`, null to leave it out
  final String? referrerPolicy;

  /// `Content-Security-Policy`, null to leave it out. The default suits an API, which never
  /// serves pages, scripts nor frames.
  final String? contentSecurityPolicy;

  /// `Strict-Transport-Security` (HSTS): only when the API is served over HTTPS (directly or by
  /// its proxy), or browsers would refuse to reach it over HTTP for [hstsMaxAge]
  final bool hsts;

  /// How long a browser remembers to use HTTPS. Default: one year.
  final Duration hstsMaxAge;

  /// Adds `includeSubDomains` to HSTS
  final bool hstsIncludeSubDomains;

  /// The headers with sensible defaults for an API
  const SecurityHeaders({
    this.referrerPolicy = 'no-referrer',
    this.contentSecurityPolicy = "default-src 'none'; frame-ancestors 'none'",
    this.hsts = false,
    this.hstsMaxAge = const Duration(days: 365),
    this.hstsIncludeSubDomains = false,
  });

  /// The headers added to a response
  Map<String, String> get headers => {
    HttpHeader.referrerPolicy: ?referrerPolicy,
    HttpHeader.contentSecurityPolicy: ?contentSecurityPolicy,
    if (hsts)
      HttpHeader.strictTransportSecurity:
          'max-age=${hstsMaxAge.inSeconds}'
          '${hstsIncludeSubDomains ? '; includeSubDomains' : ''}',
  };
}

/// Adds the [SecurityHeaders] to every response, error ones included. Added by Winter when
/// [SecurityConfig.securityHeaders] is set.
class SecurityHeadersFilter extends Filter {
  final SecurityHeaders config;

  SecurityHeadersFilter({
    this.config = const SecurityHeaders(),
    super.order = -99,
  });

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final ResponseEntity response = await chain.doFilter(request);
    final Map<String, String> missing = {
      for (final MapEntry(:key, :value) in config.headers.entries)
        if (!response.headers.containsKey(key)) key: value,
    };
    return missing.isEmpty ? response : response.change(headers: missing);
  }
}
