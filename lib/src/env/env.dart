import 'dart:io';

import 'package:collection/collection.dart';

/// The environment variables of the app, read with their type:
///
/// ```dart
/// final port = env.find<int>('PORT') ?? 8080;
/// final dbUrl = env.require<String>('DB_URL');
/// final timeout = env.find<Duration>('TIMEOUT') ?? const Duration(seconds: 30);
/// ```
///
/// Supported types: `String`, `bool`, `int`, `double`, `num`, `Duration` (`250ms`, `30s`, `5m`,
/// `1h`, `2d`), `Uri` (absolute), a `List` of any of them (comma separated), their nullable forms,
/// and enums with [findEnum]. An empty value counts as missing. A `String` is returned as it is;
/// the other types are trimmed.
///
/// [Env.load] also reads `.env` files for local development. The errors never show a value: it
/// may be a secret.
///
/// {@category Configuration}
class Env {
  final Map<String, String> _env;

  /// The active profile (`WINTER_PROFILE`), or null without one. [Env.load] reads its file.
  final String? profile;

  Env._(this._env) : profile = _blankToNull(_env[profileVariable]);

  /// The variables of the process, with [env] on top of them (handy in tests)
  factory Env({Map<String, String>? env}) {
    return Env._({...Platform.environment, ...?env});
  }

  /// The variable that selects the profile of [Env.load]
  static const String profileVariable = 'WINTER_PROFILE';

  /// The variables of the process, on top of the files `.env.<profile>` and `.env` of [directory]
  /// (in that order of precedence). The profile is [profile] or `WINTER_PROFILE`.
  ///
  /// A file that doesn't exist is ignored, so the same code runs on a laptop (with a `.env`) and in
  /// a container, where the variables come from the platform. [environment] replaces the variables
  /// of the process (for tests).
  ///
  /// The format: `KEY=VALUE`, `#` comments, empty lines, an optional `export `, and quoted values
  /// (`"..."` with `\n`, `\t`, `\"` and `\\` escapes, `'...'` literal). No interpolation.
  static Env load({
    String directory = '.',
    String? profile,
    Map<String, String>? environment,
  }) {
    final Map<String, String> process = environment ?? Platform.environment;
    final String? activeProfile =
        _blankToNull(profile) ?? _blankToNull(process[profileVariable]);
    return Env._({
      ..._readFile('$directory/.env'),
      if (activeProfile != null) ..._readFile('$directory/.env.$activeProfile'),
      ...process,
      profileVariable: ?activeProfile,
    });
  }

  /// A copy of every variable
  Map<String, String> get all => Map.from(_env);

  /// The variable [key] as a [T], or null if it's missing or empty.
  /// A value that is not a valid [T] is a [StateError] (that never shows the value).
  T? find<T>(String key, {bool caseSensitive = true}) {
    final String? raw = _rawFind(key, caseSensitive: caseSensitive);
    if (raw == null || raw.trim().isEmpty) return null;

    final _Parser parser = _parsers[T] ?? (throw _unsupportedType(T));
    return (parser.parse(raw) ?? (throw _wrongType(key, parser))) as T;
  }

  /// The variable [key] as a [T]: a [StateError] that names it if it's missing or empty
  T require<T>(String key, {bool caseSensitive = true}) =>
      find<T>(key, caseSensitive: caseSensitive) ??
      (throw StateError(
        'The env variable $key is required, and it is missing',
      ));

  /// Fails with a [StateError] that names **every** missing (or empty) variable of [keys]: in a
  /// container, finding them one restart at a time is slow
  void requireAll(Iterable<String> keys, {bool caseSensitive = true}) {
    final List<String> missing = [
      for (final key in keys)
        if (_rawFind(key, caseSensitive: caseSensitive)?.trim().isEmpty ?? true)
          key,
    ];
    if (missing.isNotEmpty) {
      throw StateError('Missing env variables: ${missing.join(', ')}');
    }
  }

  /// The variable [key] as one of the [values] of an enum, by its name (any case), or null if
  /// it's missing. Another name is a [StateError] that lists the valid ones.
  E? findEnum<E extends Enum>(
    String key,
    List<E> values, {
    bool caseSensitive = true,
  }) {
    final String? raw = _rawFind(key, caseSensitive: caseSensitive)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return values.firstWhereOrNull(
          (value) => value.name.toLowerCase() == raw.toLowerCase(),
        ) ??
        (throw StateError(
          'The env variable $key must be one of: '
          '${values.map((value) => value.name).join(', ')}',
        ));
  }

  /// Like [findEnum], but a missing variable is a [StateError]
  E requireEnum<E extends Enum>(
    String key,
    List<E> values, {
    bool caseSensitive = true,
  }) =>
      findEnum(key, values, caseSensitive: caseSensitive) ??
      (throw StateError(
        'The env variable $key is required, and it is missing',
      ));

  /// Sets [key] to [value] (written so [find] reads it back: a `List` comma separated, a
  /// `Duration` in milliseconds, an enum by name) and returns [value]
  T put<T>(String key, T value) {
    _env[key] = _format(value);
    return value;
  }

  String? _rawFind(String key, {bool caseSensitive = true}) {
    if (caseSensitive) return _env[key];
    final String lowerKey = key.toLowerCase();
    return _env.entries
        .firstWhereOrNull((entry) => entry.key.toLowerCase() == lowerKey)
        ?.value;
  }

  static String _format(Object? value) => switch (value) {
    final Iterable<Object?> items => items.map(_format).join(','),
    final Duration duration => '${duration.inMilliseconds}ms',
    final Enum value => value.name,
    _ => '$value',
  };

  static String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  static StateError _unsupportedType(Type type) => StateError(
    'Env can\'t read the type <$type>. The supported ones are String, bool, int, double, num, '
    'Duration, Uri, a List of any of them (List<String>, List<bool>, List<int>...), their '
    'nullable forms, and enums with findEnum',
  );

  static StateError _wrongType(String key, _Parser parser) =>
      StateError('The env variable $key is not ${parser.expected}');

  static Map<String, String> _readFile(String path) {
    final File file = File(path);
    if (!file.existsSync()) return {};
    return parseDotEnv(file.readAsLinesSync(), source: path);
  }

  /// Parses the lines of a `.env` file (see [load] for the format). A line that is not a
  /// variable is a [FormatException] with its line number (never its content: it may be a secret).
  static Map<String, String> parseDotEnv(
    Iterable<String> lines, {
    String source = '.env',
  }) {
    final Map<String, String> variables = {};
    var number = 0;
    for (final line in lines) {
      number++;
      var text = line.trim();
      if (text.isEmpty || text.startsWith('#')) continue;
      if (text.startsWith('export ')) text = text.substring(7).trimLeft();

      final int equals = text.indexOf('=');
      final String key = equals > 0 ? text.substring(0, equals).trim() : '';
      if (!_variableName.hasMatch(key)) {
        throw FormatException('$source:$number is not a KEY=VALUE line');
      }
      variables[key] =
          _parseValue(text.substring(equals + 1).trim()) ??
          (throw FormatException('$source:$number has an unclosed quote'));
    }
    return variables;
  }

  static final RegExp _variableName = RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*$');

  /// The value of a line: quoted (`"..."` with escapes, `'...'` literal) or not (up to a ` #`
  /// comment). Null for an unclosed quote.
  static String? _parseValue(String value) {
    if (value.startsWith("'")) {
      final int end = value.indexOf("'", 1);
      return end < 0 ? null : value.substring(1, end);
    }
    if (value.startsWith('"')) {
      final StringBuffer buffer = StringBuffer();
      for (var i = 1; i < value.length; i++) {
        final String char = value[i];
        if (char == '"') return buffer.toString();
        if (char == r'\' && i + 1 < value.length) {
          i++;
          buffer.write(switch (value[i]) {
            'n' => '\n',
            't' => '\t',
            final other => other,
          });
        } else {
          buffer.write(char);
        }
      }
      return null;
    }
    final int comment = value.indexOf(' #');
    return (comment < 0 ? value : value.substring(0, comment)).trim();
  }

  static final Map<Type, _Parser> _parsers = {
    ..._parsersOf<String>('a String', (value) => value, trim: false),
    ..._parsersOf<bool>('true or false', (value) {
      return switch (value.toLowerCase()) {
        'true' => true,
        'false' => false,
        _ => null,
      };
    }),
    ..._parsersOf<int>('an integer', int.tryParse),
    ..._parsersOf<double>('a number', (value) => double.tryParse(value)),
    ..._parsersOf<num>('a number', num.tryParse),
    ..._parsersOf<Duration>(
      'a Duration (a number and a unit: 250ms, 30s, 5m, 1h, 2d)',
      _parseDuration,
    ),
    ..._parsersOf<Uri>('an absolute URI', (value) {
      final Uri? uri = Uri.tryParse(value);
      return uri != null && uri.hasScheme ? uri : null;
    }),
  };

  /// The parsers of [T], [T]?, `List<T>` and `List<T>?`
  static Map<Type, _Parser> _parsersOf<T extends Object>(
    String expected,
    T? Function(String value) parse, {
    bool trim = true,
  }) {
    final scalar = _Parser(expected, (raw) => parse(trim ? raw.trim() : raw));
    final list = _Parser('a comma separated list of $expected', (raw) {
      final List<T> items = [];
      for (final item in raw.split(',')) {
        if (item.trim().isEmpty) continue;
        final T? parsed = parse(item.trim());
        if (parsed == null) return null;
        items.add(parsed);
      }
      return items;
    });
    return {
      T: scalar,
      _typeOf<T?>(): scalar,
      List<T>: list,
      _typeOf<List<T>?>(): list,
    };
  }

  static final RegExp _duration = RegExp(r'^(\d+)\s*(ms|s|m|h|d)$');

  static Duration? _parseDuration(String value) {
    final match = _duration.firstMatch(value.toLowerCase());
    if (match == null) return null;
    final int amount = int.parse(match[1]!);
    return switch (match[2]) {
      'ms' => Duration(milliseconds: amount),
      's' => Duration(seconds: amount),
      'm' => Duration(minutes: amount),
      'h' => Duration(hours: amount),
      _ => Duration(days: amount),
    };
  }
}

Type _typeOf<T>() => T;

class _Parser {
  /// What a valid value is, for the error
  final String expected;
  final Object? Function(String raw) parse;

  _Parser(this.expected, this.parse);
}
