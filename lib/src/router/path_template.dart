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
    /// Remove query params (if any)
    String templatePath = path.split('?').first;

    /// Replace every path param by a named group with its regex
    List<String> paramNames = [];
    String regexPattern = templatePath.replaceAllMapped(_paramPattern, (match) {
      String content = match.group(1)!;
      String regex = content.contains('|')
          ? content.split('|').skip(1).join('|')
          : r'([^/?]+)';
      paramNames.add(content.split('|').first);
      return '(?<p${paramNames.length - 1}>$regex)';
    });

    /// Add start and end to ensure a complete match
    regexPattern = '^$regexPattern\$';

    /// Make .* and .+ non-greedy by default if they are not already.
    /// This allows segments separated by literal slashes to match as expected
    /// when using regex in the path.
    regexPattern = regexPattern
        .replaceAll(RegExp(r'\.\*(?!\?)'), '.*?')
        .replaceAll(RegExp(r'\.\+(?!\?)'), '.+?');

    return PathTemplate._(RegExp(regexPattern), List.unmodifiable(paramNames));
  }

  /// True if [urlPath] (without domain, query params are ignored) match this template
  bool match(String urlPath) => _regex.hasMatch(urlPath.split('?').first);

  /// Raw (not decoded) value of every path param in [urlPath],
  /// empty if the url doesn't match this template
  Map<String, String> extract(String urlPath) {
    final RegExpMatch? match = _regex.firstMatch(urlPath.split('?').first);
    if (match == null) return {};

    return {
      for (int i = 0; i < _paramNames.length; i++)
        _paramNames[i]: match.namedGroup('p$i') ?? '',
    };
  }
}
