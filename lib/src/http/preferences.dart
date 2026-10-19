/// The preferences a client sent in `Prefer` (RFC 7240): what it would like, which the server may
/// honor or ignore. Read them with `request.preferences`:
///
/// ```dart
/// final Note note = store.create(await request.body<NewNote>());
/// if (request.preferences.returns == 'minimal') {
///   return ResponseEntity.created(
///     location: '/notes/${note.id}',
///     headers: {HttpHeader.preferenceApplied: 'return=minimal'},
///   );
/// }
/// return ResponseEntity.created(location: '/notes/${note.id}', body: note);
/// ```
///
/// Reading them inside a request adds `Vary: Prefer` to its response, so a cache keeps one copy
/// per preference. Tell the client what was honored with `Preference-Applied`.
///
/// {@category HTTP}
final class Preferences {
  /// Every preference by its name in lower case, in the order they came; when a name comes twice,
  /// the first one (RFC 7240 §2)
  final Map<String, Preference> all;

  /// The preferences of [all]
  const Preferences(this.all);

  /// No preference
  static const Preferences none = Preferences({});

  /// The preferences of the values of `Prefer` (several headers, or several preferences separated
  /// by commas, are one list). A malformed part is skipped.
  factory Preferences.parse(Iterable<String> headers) {
    final Map<String, Preference> all = {};
    for (final String header in headers) {
      for (final String part in _split(header, ',')) {
        final List<String> pieces = _split(part, ';');
        final (String, String?)? pair = _pair(pieces.first);
        if (pair == null) continue;
        all.putIfAbsent(
          pair.$1,
          () => Preference(pair.$2, {
            for (final String piece in pieces.skip(1))
              if (_pair(piece) case (final String name, final String? value))
                name: value,
          }),
        );
      }
    }
    return Preferences(all);
  }

  /// The value of the preference [name] (case insensitive), or null when it has none or didn't
  /// come; use [has] to tell them apart
  String? operator [](String name) => all[name.toLowerCase()]?.value;

  /// Whether the preference [name] (case insensitive) came
  bool has(String name) => all.containsKey(name.toLowerCase());

  /// `return`: `minimal` (only a status and the headers that matter, like `Location`) or
  /// `representation` (the whole resource), or null
  String? get returns => this['return']?.toLowerCase();

  /// `respond-async`: the client would rather get a `202 Accepted` than wait
  bool get respondAsync => has('respond-async');

  /// `wait`: how long the client is willing to wait for the response, or null (or not a number
  /// of seconds)
  Duration? get wait {
    final int? seconds = int.tryParse(this['wait'] ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  /// `handling`: `strict` (reject anything invalid) or `lenient` (do what can be done), or null
  String? get handling => this['handling']?.toLowerCase();

  @override
  String toString() => 'Preferences(${all.keys.join(', ')})';

  /// `name` or `name=value` (a token or a quoted string), the name in lower case; null when it's
  /// not one
  static (String, String?)? _pair(String text) {
    final int equals = text.indexOf('=');
    final String name = (equals < 0 ? text : text.substring(0, equals))
        .trim()
        .toLowerCase();
    if (!_token.hasMatch(name)) return null;
    if (equals < 0) return (name, null);
    final String value = text.substring(equals + 1).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return (
        name,
        value
            .substring(1, value.length - 1)
            .replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!),
      );
    }
    return (name, value.isEmpty ? null : value);
  }

  static final RegExp _token = RegExp(r"^[A-Za-z0-9!#$%&'*+.^_`|~-]+$");

  /// [text] split by [separator] outside quoted strings
  static List<String> _split(String text, String separator) {
    final List<String> parts = [];
    final StringBuffer part = StringBuffer();
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final String char = text[i];
      if (quoted && char == r'\' && i + 1 < text.length) {
        part
          ..write(char)
          ..write(text[++i]);
        continue;
      }
      if (char == '"') quoted = !quoted;
      if (char == separator && !quoted) {
        parts.add(part.toString());
        part.clear();
      } else {
        part.write(char);
      }
    }
    parts.add(part.toString());
    return parts.where((part) => part.trim().isNotEmpty).toList();
  }
}

/// One preference of `Prefer`: its value (`minimal` in `return=minimal`), and its parameters
///
/// {@category HTTP}
final class Preference {
  /// The value, or null when it has none (`respond-async`)
  final String? value;

  /// The parameters after `;`, by name in lower case
  final Map<String, String?> params;

  /// A preference with [value] and [params]
  const Preference(this.value, [this.params = const {}]);
}
