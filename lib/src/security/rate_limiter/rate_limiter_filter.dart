import 'dart:async';

import 'package:winter/winter.dart';

/// A filter that limits the number of requests a client can make within a given time window.
///
/// It uses a [RateLimiter] to track requests, per client: [clientId] identifies it (by default, the
/// IP of the client; behind proxies use
/// `clientId: (request) => request.clientIp(trustedProxies: 1) ?? 'unknown'`).
///
/// {@category Security}
class RateLimiterFilter extends Filter {
  /// The underlying rate limiter implementation.
  final RateLimiter rateLimiter;

  /// The id of the client of a request, whose requests are limited (the IP by default)
  final FutureOr<String> Function(RequestEntity request) clientId;

  /// Called for every rejected request (a debug log by default), or null for nothing
  final void Function(RequestEntity request, String clientId)? onLimited;

  /// At most [maxRequests] per client in every [window] (a sliding window, in memory)
  RateLimiterFilter({
    required int maxRequests,
    required Duration window,
    this.clientId = defaultClientId,
    this.onLimited = defaultLogRateLimiter,
  }) : rateLimiter = RateLimiter(maxRequests, window);

  /// A filter over [rateLimiter]: a [RateLimiter] with another store (shared by several
  /// instances) or clock
  RateLimiterFilter.fromRateLimiter({
    required this.rateLimiter,
    this.clientId = defaultClientId,
    this.onLimited = defaultLogRateLimiter,
  });

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String id = await clientId(request);
    final RateLimitResult result = await rateLimiter.check(id);

    // Standard Rate Limit headers
    // Reset: seconds until the oldest request leaves the window (a new slot is available)
    final rateLimitHeaders = {
      'X-RateLimit-Limit': '${result.limit}',
      'X-RateLimit-Remaining': '${result.remaining}',
      'X-RateLimit-Reset': '${_ceilSeconds(result.resetAfter)}',
    };

    if (!result.allowed) {
      onLimited?.call(request, id);
      final wait = _ceilSeconds(result.retryAfter);
      throw TooManyRequestsException(
        retryAfter: wait > 0 ? wait : 1,
        headers: rateLimitHeaders,
      );
    }

    final response = await chain.doFilter(request);
    // Add headers to the successful response
    return response.copyWith(headers: rateLimitHeaders);
  }

  /// Round up, so a client waiting the given seconds is never too early
  static int _ceilSeconds(Duration duration) =>
      (duration.inMicroseconds / Duration.microsecondsPerSecond).ceil();
}

/// Debug level: under an attack there is one log per rejected request,
/// at info level it would flood the logs
///
/// {@category Security}
void defaultLogRateLimiter(RequestEntity request, String clientId) {
  ///Skipped before building the message: under an attack there is one per rejected request
  if (!logger.isEnabled(LogLevel.debug)) return;
  logger.debug(
    'Rate limit exceeded for id: $clientId in ${request.method} ${request.requestedUri.path}',
  );
}

/// Identify the client by its IP (the address of the connection, see [RequestEntity.clientIp])
///
/// {@category Security}
String defaultClientId(RequestEntity request) =>
    request.clientIp() ?? 'unknown';
