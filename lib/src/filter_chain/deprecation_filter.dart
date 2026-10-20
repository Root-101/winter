import 'dart:io' show HttpDate;

import 'package:winter/winter.dart';

/// Marks every response of its routes as deprecated, with the headers that clients, gateways
/// and linters read without knowing the API:
///
/// - `Deprecation` (RFC 9745): the date from which the routes are deprecated (`@1767225600`, a
///   past or a future one).
/// - `Sunset` (RFC 8594): the date from which they may stop answering.
/// - `Link`: the documentation of the deprecation (`rel="deprecation"`) and the same resource in
///   the version that replaces it (`rel="successor-version"`, RFC 5829), after any other `Link`
///   of the response.
///
/// Put it in the `FilterConfig` of a parent to deprecate a whole version; its children inherit
/// it, its errors carry the headers too, and OpenAPI marks its operations `deprecated: true`:
///
/// ```dart
/// Route.parent(
///   path: '/v1',
///   filterConfig: FilterConfig([
///     DeprecationFilter(
///       deprecated: DateTime.utc(2026, 7),
///       sunset: DateTime.utc(2027),
///       link: Uri.parse('https://api.example.com/docs/v2-migration'),
///       successor: (request) => request.requestedUri.path.replaceFirst('/v1/', '/v2/'),
///     ),
///   ]),
///   routes: [...],
/// )
/// ```
///
/// {@category Filters}
class DeprecationFilter extends Filter {
  /// Since when the routes are deprecated (sent with a precision of seconds)
  final DateTime deprecated;

  /// When the routes may stop answering, or null when it isn't decided yet
  final DateTime? sunset;

  /// The documentation of the deprecation (how to migrate), or null
  final Uri? link;

  /// The URI (absolute, or relative to the request) of the same resource in the version that
  /// replaces this one, or null
  final String Function(RequestEntity request)? successor;

  /// Routes deprecated since [deprecated]. A [sunset] before [deprecated] is an [ArgumentError]
  /// (RFC 9745: a resource can't stop answering before it's deprecated).
  DeprecationFilter({
    required this.deprecated,
    this.sunset,
    this.link,
    this.successor,
  }) {
    final DateTime? sunset = this.sunset;
    if (sunset != null && sunset.isBefore(deprecated)) {
      throw ArgumentError.value(
        sunset,
        'sunset',
        'Must not be before the deprecation ($deprecated)',
      );
    }
  }

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final ResponseEntity response = await chain.doFilter(request);
    final Uri? link = this.link;
    final String? successor = this.successor?.call(request);
    final DateTime? sunset = this.sunset;
    return response.copyWith(
      headers: {
        // A Structured Field Date: seconds since the epoch (RFC 9651)
        HttpHeader.deprecation: '@${deprecated.millisecondsSinceEpoch ~/ 1000}',
        if (sunset != null) HttpHeader.sunset: HttpDate.format(sunset),
        if (link != null || successor != null)
          HttpHeader.link: [
            ...?response.headersAll[HttpHeader.link],
            if (link != null)
              WebLink(link, rel: 'deprecation', type: 'text/html'),
            if (successor != null)
              WebLink(Uri.parse(successor), rel: 'successor-version'),
          ],
      },
    );
  }
}
