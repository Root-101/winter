import 'dart:math';

import 'package:winter/winter.dart';

/// A link of the `Link` header (RFC 8288): a target and its relation to the response
/// (`rel="next"`), with optional attributes. Written as `<target>; rel="next"; title="..."`, so a
/// list of them is the value of the header:
///
/// ```dart
/// ResponseEntity.ok(
///   body: page,
///   headers: {
///     HttpHeader.link: [
///       ...WebLink.pages(request, page: 2, last: 5),
///       WebLink(Uri.parse('https://api.example.com/docs'), rel: 'help', type: 'text/html'),
///     ],
///   },
/// );
/// ```
///
/// {@category HTTP}
final class WebLink {
  /// The URI the link points to: absolute, or relative to the request
  final Uri target;

  /// The relation type: a registered one (`next`, `prev`, `first`, `last`, `self`, `help`...) or
  /// an absolute URI. Several are separated by spaces.
  final String rel;

  /// The media type of the target (`text/html`), or null
  final String? type;

  /// A title for a person, or null
  final String? title;

  /// The language of the target (`es`), or null
  final String? hreflang;

  /// More attributes (`{'anchor': '#comments'}`), written after the others
  final Map<String, String> params;

  /// A link to [target] with its relation [rel]. An attribute that isn't printable ASCII is an
  /// [ArgumentError] (a header can only carry those).
  WebLink(
    this.target, {
    required this.rel,
    this.type,
    this.title,
    this.hreflang,
    this.params = const {},
  }) {
    for (final MapEntry(:key, :value) in {
      'rel': rel,
      'type': ?type,
      'title': ?title,
      'hreflang': ?hreflang,
      ...params,
    }.entries) {
      if (!_printableAscii.hasMatch(value) || !_token.hasMatch(key)) {
        throw ArgumentError.value(value, key, 'must be printable ASCII');
      }
    }
  }

  static final RegExp _printableAscii = RegExp(r'^[\x20-\x7E]+$');
  static final RegExp _token = RegExp(r"^[A-Za-z0-9!#$%&'*+.^_`|~-]+$");

  /// The links of a page of a list: `first`, `prev` (unless [page] is the first), `next` (unless
  /// it's the [last]) and `last`. Each one is the URL of [request] with only the query param
  /// [param] changed, so the other params (the size, a filter, a sort) are kept; relative to the
  /// request (`/articles?page=3&size=5`), the same behind any proxy.
  ///
  /// A [last] under 1 (an empty list) is taken as 1.
  static List<WebLink> pages(
    RequestEntity request, {
    required int page,
    required int last,
    String param = 'page',
  }) {
    final int lastPage = max(last, 1);
    final Uri uri = request.requestedUri;
    WebLink link(int number, String rel) {
      final Uri page = uri.replace(
        queryParameters: {
          ...uri.queryParametersAll,
          param: ['$number'],
        },
      );
      return WebLink(
        Uri(path: page.path, query: page.query),
        rel: rel,
      );
    }

    return [
      link(1, 'first'),
      if (page > 1) link(min(page - 1, lastPage), 'prev'),
      if (page < lastPage) link(page + 1, 'next'),
      link(lastPage, 'last'),
    ];
  }

  /// A quoted string: `\` and `"` escaped
  static String _quoted(String value) =>
      '"${value.replaceAllMapped(RegExp(r'[\\"]'), (m) => '\\${m[0]}')}"';

  @override
  String toString() => [
    '<$target>',
    'rel=${_quoted(rel)}',
    if (type != null) 'type=${_quoted(type!)}',
    if (title != null) 'title=${_quoted(title!)}',
    if (hreflang != null) 'hreflang=${_quoted(hreflang!)}',
    for (final MapEntry(:key, :value) in params.entries)
      '$key=${_quoted(value)}',
  ].join('; ');
}
