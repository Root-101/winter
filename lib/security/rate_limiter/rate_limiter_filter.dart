import 'dart:async';
import 'dart:io';

import 'package:winter/winter.dart';

/// A filter that limits the number of requests a client can make within a given time window.
///
/// It uses a [RateLimiter] to track requests and can be configured to identify
/// clients based on a custom [onRequest] function.
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
    required this.onRequest,
    this.log = defaultLogRateLimiter,
  }) : rateLimiter = RateLimiter(maxRequests, window);

  RateLimiterFilter.fromRateLimiter({
    required this.rateLimiter,
    required this.onRequest,
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
    final windowSeconds = rateLimiter.window.inSeconds;

    // Standard Rate Limit headers
    final rateLimitHeaders = {
      'X-RateLimit-Limit': '$limit',
      'X-RateLimit-Remaining': '$remaining',
      'X-RateLimit-Reset': '$windowSeconds',
    };

    if (allowed) {
      final response = await chain.doFilter(request);

      // Add headers to the successful response
      return response.copyWith(
        headers: {...response.headers, ...rateLimitHeaders},
      );
    } else {
      log?.call(request, requestId);

      final wait = rateLimiter.getWaitDuration(requestId);

      return ResponseEntity.tooManyRequests(
        retryAfter: wait.inSeconds > 0 ? wait.inSeconds : 1,
        headers: rateLimitHeaders,
      );
    }
  }
}

void defaultLogRateLimiter(dynamic request, dynamic requestId) {
  stdout.writeln(
    'Rate limiter fail for id: $requestId in request: ${request.url}',
  );
}
