import 'dart:async';
import 'dart:io' show InternetAddress, InternetAddressType;

import 'package:winter/winter.dart';

/// A filter that limits the number of requests a client can make within a given time window.
///
/// It uses a [RateLimiter] to track requests, per client: [clientId] identifies it (by default,
/// [RequestEntity.clientIp]; behind proxies, set [ServerConfig.trustedProxies] so it's the IP
/// they forward).
///
/// Every response it lets through, and its 429, carry the headers of the IETF draft
/// *RateLimit header fields for HTTP* (`draft-ietf-httpapi-ratelimit-headers`):
///
/// ```http
/// RateLimit-Policy: "default";q=100;w=60
/// RateLimit: "default";r=42;t=17
/// ```
///
/// `q` is [RateLimiter.maxRequests], `w` the window in seconds, `r` the requests left and `t` the
/// seconds until one more is available. Several filters on a route (a `burst` and a `daily` one)
/// add one item each: give each a [policy] name of its own.
///
/// {@category Security}
class RateLimiterFilter extends Filter {
  /// The underlying rate limiter implementation.
  final RateLimiter rateLimiter;

  /// The id of the client of a request, whose requests are limited (the IP by default)
  final FutureOr<String> Function(RequestEntity request) clientId;

  /// Called for every rejected request (a debug log by default), or null for nothing
  final void Function(RequestEntity request, String clientId)? onLimited;

  /// The name of the quota policy in the `RateLimit-Policy` and `RateLimit` headers: printable
  /// ASCII (an [ArgumentError] otherwise)
  final String policy;

  final String _policyItem;

  /// At most [maxRequests] per client in every [window] (a sliding window, in memory)
  RateLimiterFilter({
    required int maxRequests,
    required Duration window,
    this.clientId = defaultClientId,
    this.onLimited = defaultLogRateLimiter,
    this.policy = 'default',
  }) : rateLimiter = RateLimiter(maxRequests: maxRequests, window: window),
       _policyItem = _structuredString(policy);

  /// A filter over [rateLimiter]: a [RateLimiter] with another store (shared by several
  /// instances) or clock
  RateLimiterFilter.fromRateLimiter({
    required this.rateLimiter,
    this.clientId = defaultClientId,
    this.onLimited = defaultLogRateLimiter,
    this.policy = 'default',
  }) : _policyItem = _structuredString(policy);

  static final RegExp _printableAscii = RegExp(r'^[\x20-\x7E]*$');

  /// [value] as a String of a Structured Field (RFC 9651): quoted, with `\` and `"` escaped
  static String _structuredString(String value) {
    if (!_printableAscii.hasMatch(value)) {
      throw ArgumentError.value(value, 'policy', 'must be printable ASCII');
    }
    return '"${value.replaceAllMapped(RegExp(r'[\\"]'), (m) => '\\${m[0]}')}"';
  }

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String id = await clientId(request);
    final RateLimitResult result = await rateLimiter.check(id);

    // w can't be zero nor have a fraction: a window under a second is announced as one
    final int window = _ceilSeconds(rateLimiter.window);
    final String policyItem = '$_policyItem;q=${result.limit};w=$window';
    // t: seconds until the oldest request leaves the window (one more is available then)
    final String limitItem =
        '$_policyItem;r=${result.remaining};t=${_ceilSeconds(result.resetAfter)}';

    if (!result.allowed) {
      onLimited?.call(request, id);
      final wait = _ceilSeconds(result.retryAfter);
      throw TooManyRequestsException(
        retryAfter: wait > 0 ? wait : 1,
        headers: {
          HttpHeader.rateLimitPolicy: policyItem,
          HttpHeader.rateLimit: limitItem,
        },
      );
    }

    final response = await chain.doFilter(request);
    // Appended, not replaced: an inner filter (another policy) may have added its own item
    return response.copyWith(
      headers: {
        HttpHeader.rateLimitPolicy: [
          ...?response.headersAll[HttpHeader.rateLimitPolicy],
          policyItem,
        ],
        HttpHeader.rateLimit: [
          ...?response.headersAll[HttpHeader.rateLimit],
          limitItem,
        ],
      },
    );
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
  /// Skipped before building the message: under an attack there is one per rejected request
  if (!logger.isEnabled(LogLevel.debug)) return;
  logger.debug(
    'Rate limit exceeded for id: $clientId in ${request.method} ${request.requestedUri.path}',
  );
}

/// Identify the client by its IP (the address of the connection, see [RequestEntity.clientIp]).
/// An IPv6 address counts by its /64 (`2001:db8:0:1::/64`): one host usually has a whole /64 and
/// could take a new address for every request. An IPv4 one, mapped or not, is the address.
///
/// {@category Security}
String defaultClientId(RequestEntity request) {
  final String? ip = request.clientIp;
  if (ip == null) return 'unknown';
  final InternetAddress? address = InternetAddress.tryParse(ip);
  if (address == null || address.type != InternetAddressType.IPv6) return ip;
  final List<int> bytes = address.rawAddress;
  final bool mappedIPv4 =
      bytes.take(10).every((byte) => byte == 0) &&
      bytes[10] == 0xFF &&
      bytes[11] == 0xFF;
  if (mappedIPv4) return ip;
  return '${[for (var i = 0; i < 8; i += 2) ((bytes[i] << 8) | bytes[i + 1]).toRadixString(16)].join(':')}::/64';
}
