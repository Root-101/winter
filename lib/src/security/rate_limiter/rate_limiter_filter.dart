import 'dart:async';

import 'package:winter/winter.dart';

/// A filter that limits the number of requests a client can make within a given time window.
///
/// It uses a [RateLimiter] to track requests and can be configured to identify
/// clients based on a custom [onRequest] function (by default, the IP of the client:
/// behind proxies use `onRequest: (request) => request.clientIp(trustedProxies: 1) ?? 'unknown'`).
class RateLimiterFilter extends Filter {
  /// The underlying rate limiter implementation.
  final RateLimiter rateLimiter;

  /// A function that extracts a unique identifier for the client from the request.
  final FutureOr<String> Function(RequestEntity request) onRequest;

  /// An optional logging function called when a request is rate limited.
  final void Function(RequestEntity request, String requestId)? log;

  RateLimiterFilter({
    required int maxRequests,
    required Duration window,
    this.onRequest = clientIpRequestId,
    this.log = defaultLogRateLimiter,
  }) : rateLimiter = RateLimiter(maxRequests, window);

  RateLimiterFilter.fromRateLimiter({
    required this.rateLimiter,
    this.onRequest = clientIpRequestId,
    this.log = defaultLogRateLimiter,
  });

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final requestId = await onRequest.call(request);

    final allowed = rateLimiter.allowRequest(requestId);
    final remaining = rateLimiter.getRemaining(requestId);
    final limit = rateLimiter.maxRequests;
    final resetSeconds = _ceilSeconds(rateLimiter.getResetDuration(requestId));

    // Standard Rate Limit headers
    // Reset: seconds until the oldest request leaves the window (a new slot is available)
    final rateLimitHeaders = {
      'X-RateLimit-Limit': '$limit',
      'X-RateLimit-Remaining': '$remaining',
      'X-RateLimit-Reset': '$resetSeconds',
    };

    if (allowed) {
      final response = await chain.doFilter(request);

      // Add headers to the successful response
      return response.change(headers: rateLimitHeaders);
    } else {
      log?.call(request, requestId);

      final wait = _ceilSeconds(rateLimiter.getWaitDuration(requestId));

      throw TooManyRequestsException(
        retryAfter: wait > 0 ? wait : 1,
        headers: rateLimitHeaders,
      );
    }
  }

  /// Round up, so a client waiting the given seconds is never too early
  static int _ceilSeconds(Duration duration) =>
      (duration.inMicroseconds / Duration.microsecondsPerSecond).ceil();
}

/// Debug level: under an attack there is one log per rejected request,
/// at info level it would flood the logs
void defaultLogRateLimiter(RequestEntity request, String requestId) {
  logger.debug(
    'Rate limit exceeded for id: $requestId in ${request.method} ${request.requestedUri.path}',
  );
}

/// Identify the client by its IP (the address of the connection, see [RequestEntity.clientIp])
String clientIpRequestId(RequestEntity request) =>
    request.clientIp() ?? 'unknown';
