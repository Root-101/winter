import 'package:winter/winter.dart';

/// Base class for security configuration in Winter.
/// Users can extend this class to customize security features like CORS.
class SecurityConfig {
  final CorsConfig? _cors;

  SecurityConfig({this._cors});

  /// Returns the CORS configuration.
  /// If it returns null, [CorsFilter] will not be automatically applied.
  CorsConfig? cors() => _cors;
}

/// Configuration for Cross-Origin Resource Sharing (CORS).
class CorsConfig {
  final List<String> allowedOrigins;
  final List<String> allowedMethods;
  final List<String> allowedHeaders;
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
