/// A route path (like `/users/{id}` or `/files/.*`) compiled once:
/// the regex to match urls and the names of its path params.
///
/// Compiling the regex is expensive, so templates are cached by path and
/// every request reuses them (routes are a small & fixed set of paths).
class PathTemplate {
  /// Path params: `{name}` or `{name|regex}`
  static final RegExp _paramPattern = RegExp(r'{([^}]+)}');

  static final Map<String, PathTemplate> _cache = {};

  final RegExp _regex;

  /// Name of every path param, in order (the regex groups are `p0`, `p1`...)
  final List<String> _paramNames;

  PathTemplate._(this._regex, this._paramNames);

  factory PathTemplate.of(String path) =>
      _cache[path] ??= PathTemplate._compile(path);

  factory PathTemplate._compile(String path) {
    /// Remove the trailing slash. A route has no query: a `?` is part of a regex (`{id|\d?}`)
    String templatePath = normalizePath(path);

    /// Replace every path param by a named group with its regex,
    /// the literal parts between them are kept as regex but with their dots escaped
    List<String> paramNames = [];
    StringBuffer buffer = StringBuffer('^');
    int lastEnd = 0;
    for (final match in _paramPattern.allMatches(templatePath)) {
      buffer.write(
        _escapeLiteralDots(templatePath.substring(lastEnd, match.start)),
      );

      String content = match.group(1)!;
      String regex = content.contains('|')
          ? content.split('|').skip(1).join('|')
          : r'([^/?]+)';
      paramNames.add(content.split('|').first);
      buffer.write('(?<p${paramNames.length - 1}>$regex)');

      lastEnd = match.end;
    }
    buffer.write(_escapeLiteralDots(templatePath.substring(lastEnd)));
    buffer.write(r'$');

    /// Make .* and .+ non-greedy by default if they are not already.
    /// This allows segments separated by literal slashes to match as expected
    /// when using regex in the path.
    String regexPattern = buffer
        .toString()
        .replaceAll(RegExp(r'\.\*(?!\?)'), '.*?')
        .replaceAll(RegExp(r'\.\+(?!\?)'), '.+?');

    return PathTemplate._(RegExp(regexPattern), List.unmodifiable(paramNames));
  }

  /// A dot alone is a literal dot (`/file.json` doesn't match `/fileXjson`),
  /// only `.*`, `.+`, `.?` & `.{n}` (and already escaped dots) are kept as regex
  static String _escapeLiteralDots(String literal) =>
      literal.replaceAll(RegExp(r'(?<!\\)\.(?![*+?{])'), r'\.');

  /// True if [urlPath] (without domain, query params are ignored) match this template
  bool match(String urlPath) =>
      _regex.hasMatch(normalizePath(urlPath.split('?').first));

  /// Raw (not decoded) value of every path param in [urlPath],
  /// empty if the url doesn't match this template
  Map<String, String> extract(String urlPath) {
    final RegExpMatch? match = _regex.firstMatch(
      normalizePath(urlPath.split('?').first),
    );
    if (match == null) return {};

    return {
      for (int i = 0; i < _paramNames.length; i++)
        _paramNames[i]: match.namedGroup('p$i') ?? '',
    };
  }
}

/// Remove the trailing slash of a path (`/users/` => `/users`), except for the root (`/`).
/// So a route match its path with or without the trailing slash.
String normalizePath(String path) {
  String normalized = path;
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}
