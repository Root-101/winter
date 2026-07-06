import 'dart:async';

import 'package:winter/winter.dart';

/// A filter that handles CORS preflight requests and adds CORS headers to responses.
class CorsFilter extends Filter {
  final CorsConfig config;

  CorsFilter({this.config = const CorsConfig(), super.order = -100});

  @override
  FutureOr<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (request.method.toLowerCase() == HttpMethod.options.name.toLowerCase() &&
        request.headers.containsKey(HttpHeaders.accessControlRequestMethod)) {
      return _handlePreflight(request);
    }

    final response = await chain.doFilter(request);
    return _addCorsHeaders(request, response);
  }

  ResponseEntity _handlePreflight(RequestEntity request) {
    final headers = _getCorsHeaders(request);
    return ResponseEntity.ok(headers: headers);
  }

  ResponseEntity _addCorsHeaders(
    RequestEntity request,
    ResponseEntity response,
  ) {
    final corsHeaders = _getCorsHeaders(request);
    final newHeaders = {...response.headers, ...corsHeaders};
    return response.copyWith(headers: newHeaders);
  }

  Map<String, String> _getCorsHeaders(RequestEntity request) {
    final headers = <String, String>{};

    final origin =
        request.headers[HttpHeaders.origin] ??
        request.headers[HttpHeaders.origin];

    if (config.allowedOrigins.contains('*')) {
      headers[HttpHeaders.accessControlAllowOrigin] = '*';
    } else if (origin != null && config.allowedOrigins.contains(origin)) {
      headers[HttpHeaders.accessControlAllowOrigin] = origin;
      headers[HttpHeaders.vary] = HttpHeaders.origin;
    }

    if (config.allowCredentials) {
      headers[HttpHeaders.accessControlAllowCredentials] = 'true';
    }

    if (config.exposedHeaders.isNotEmpty) {
      headers[HttpHeaders.accessControlExposeHeaders] = config.exposedHeaders
          .join(', ');
    }

    if (request.method.toLowerCase() == HttpMethod.options.name.toLowerCase()) {
      headers[HttpHeaders.accessControlAllowMethods] = config.allowedMethods
          .join(', ');

      final requestedHeaders =
          request.headers[HttpHeaders.accessControlRequestHeaders];
      if (config.allowedHeaders.contains('*')) {
        if (requestedHeaders != null) {
          headers[HttpHeaders.accessControlAllowHeaders] = requestedHeaders;
        }
      } else if (config.allowedHeaders.isNotEmpty) {
        headers[HttpHeaders.accessControlAllowHeaders] = config.allowedHeaders
            .join(', ');
      }

      if (config.maxAge != null) {
        headers[HttpHeaders.accessControlMaxAge] = config.maxAge.toString();
      }
    }

    return headers;
  }
}
