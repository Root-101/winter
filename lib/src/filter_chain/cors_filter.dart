import 'dart:async';

import 'package:winter/winter.dart';

/// A filter that handles CORS preflight requests and adds CORS headers to responses.
class CorsFilter extends Filter {
  final CorsConfig config;

  CorsFilter({this.config = const CorsConfig(), super.order = -100}) {
    if (config.allowCredentials && config.allowedOrigins.contains('*')) {
      logger.warning(
        "CORS allows '*' with credentials: the origin of every request is echoed, so any "
        'website can read the API with the cookies of its user. List the allowed origins.',
      );
    }
  }

  /// With '*' and no credentials the answer is the same for every origin; otherwise it
  /// depends on the `Origin` of the request (even when it's missing or not allowed)
  bool get _dependsOnOrigin =>
      !config.allowedOrigins.contains('*') || config.allowCredentials;

  @override
  FutureOr<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (request.method.toLowerCase() == HttpMethod.options.name.toLowerCase() &&
        request.headers.containsKey(HttpHeader.accessControlRequestMethod)) {
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

    ///Merged with the `Vary` of the response (ex: `Cookie`), not replaced
    final String? vary = corsHeaders.remove(HttpHeader.vary);
    final ResponseEntity withCors = corsHeaders.isEmpty
        ? response
        : response.copyWith(headers: corsHeaders);
    return vary == null ? withCors : addVary(withCors, vary);
  }

  Map<String, String> _getCorsHeaders(RequestEntity request) {
    final headers = <String, String>{};

    final origin = request.headers[HttpHeader.origin];

    ///'Vary: Origin' for every response that depends on it, so a cache never gives a response
    ///prepared for one origin to another (a disallowed one, or a request without Origin)
    if (_dependsOnOrigin) headers[HttpHeader.vary] = HttpHeader.origin;

    if (origin == null) return headers;

    if (config.allowedOrigins.contains('*') && !config.allowCredentials) {
      headers[HttpHeader.accessControlAllowOrigin] = '*';
    } else if (config.allowedOrigins.contains('*') ||
        config.allowedOrigins.contains(origin)) {
      ///Browsers reject '*' with credentials, so the origin is echoed instead
      ///(and 'Vary: Origin' tells caches that the response depends on it)
      headers[HttpHeader.accessControlAllowOrigin] = origin;
    }

    if (config.allowCredentials) {
      headers[HttpHeader.accessControlAllowCredentials] = 'true';
    }

    ///The id of the request is always readable, so a web client can report it
    headers[HttpHeader.accessControlExposeHeaders] = {
      HttpHeader.xRequestId,
      ...config.exposedHeaders,
    }.join(', ');

    if (request.method.toLowerCase() == HttpMethod.options.name.toLowerCase()) {
      headers[HttpHeader.accessControlAllowMethods] = config.allowedMethods
          .join(', ');

      final requestedHeaders =
          request.headers[HttpHeader.accessControlRequestHeaders];
      if (config.allowedHeaders.contains('*')) {
        if (requestedHeaders != null) {
          headers[HttpHeader.accessControlAllowHeaders] = requestedHeaders;
        }
      } else if (config.allowedHeaders.isNotEmpty) {
        headers[HttpHeader.accessControlAllowHeaders] = config.allowedHeaders
            .join(', ');
      }

      if (config.maxAge != null) {
        headers[HttpHeader.accessControlMaxAge] = config.maxAge.toString();
      }
    }

    return headers;
  }
}
