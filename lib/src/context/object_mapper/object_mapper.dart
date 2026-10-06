import 'dart:convert';

import 'package:winter/winter.dart';

/// How the field names of the objects are written in JSON, see [ObjectMapper.fieldNaming]
enum FieldNaming {
  /// As the model writes them (`userId`)
  none,

  /// `user_id`
  snakeCase,

  /// `user-id`
  kebabCase,
}

/// How a [Duration] is written in JSON, see [ObjectMapper.durationFormat]
enum DurationFormat {
  /// An integer: `5400000`
  milliseconds,

  /// ISO-8601: `PT1H30M`
  iso8601,
}

/// Common base for Serializers and Deserializers to handle type inference warnings.
abstract class _MapperEntity<T> {
  final Type type;

  _MapperEntity({bool warnDynamic = true}) : type = T {
    if (warnDynamic && T == dynamic) {
      logger.warning(
        'Unable to infer type for $runtimeType. '
        'The registry was made as "dynamic", which usually happens when '
        'the generic type argument is omitted. '
        'Declare it explicitly, for example: '
        '${runtimeType.toString().split('<').first}<YOUR_TYPE>((value) => ...)',
      );
    }
  }
}

/// Converts a [T] into a JSON value. It also applies to the subtypes of [T]
/// (when they have no serializer of their own), so it works with `freezed` and sealed classes.
///
/// The result is serialized again, so it can return maps with any serializable value.
class Serializer<T> extends _MapperEntity<T> {
  final Object? Function(T object, ObjectMapper mapper) _serialize;

  Serializer(Object? Function(T object) serializer)
    : _serialize = ((object, _) => serializer(object));

  Serializer._withMapper(this._serialize) : super(warnDynamic: false);

  bool _accepts(Object object) => object is T;

  Object? _call(Object object, ObjectMapper mapper) =>
      _serialize(object as T, mapper);
}

/// Converts a JSON value (already decoded) into a [T].
///
/// Registering it in an [ObjectMapper] also registers the deserializers of `T?`, `List<T>`,
/// `Set<T>`, `Map<String, T>`, the nullable form of each collection, `List<T?>` and
/// `Map<String, T?>`. Deeper types are registered explicitly with [list], [set], [map] and
/// [nullable]: `Deserializer<User>.json(User.fromJson).list()` gives `List<List<User>>` too.
class Deserializer<T> extends _MapperEntity<T> {
  final T Function(Object? data, ObjectMapper mapper) _deserialize;

  /// [deserializer] receives the decoded JSON value. If it throws, the client gets a 400
  /// (`invalid value for T`) and the original error is logged at debug.
  Deserializer(T Function(dynamic data) deserializer)
    : _deserialize = ((data, _) => deserializer(data));

  /// Deserializer for a JSON object, [fromJson] receives the already checked map:
  ///
  /// ```dart
  /// Deserializer<User>.json(User.fromJson)
  /// ```
  ///
  /// If the data is not a JSON object, a [DeserializationException] (400) is thrown.
  /// The keys of the map follow [ObjectMapper.fieldNaming].
  ///
  /// Declare the type explicitly inside a list (`[Deserializer<User>.json(User.fromJson)]`),
  /// otherwise the type of the list wins and it's registered as `dynamic`.
  Deserializer.json(T Function(Map<String, dynamic> json) fromJson)
    : _deserialize = ((data, mapper) =>
          fromJson(mapper._jsonKeysToDart(_asJsonObject(data))));

  Deserializer._withMapper(this._deserialize) : super(warnDynamic: false);

  /// Runs the deserializer: any error that is not already a [DeserializationException]
  /// (a cast in a `fromJson`, a parser...) is a 400 without its details.
  T _call(Object? data, ObjectMapper mapper) {
    try {
      return _deserialize(data, mapper);
    } on DeserializationException {
      rethrow;
    } on ApiException {
      rethrow;
    } on MissingDeserializerError {
      rethrow;
    } catch (e) {
      logger.debug('Invalid value for <$T>: $e');
      throw DeserializationException('invalid value for $T', cause: e);
    }
  }

  /// Deserializer of a JSON array of [T]
  Deserializer<List<T>> list() => Deserializer<List<T>>._withMapper(
    (data, mapper) => _listOf(data, mapper),
  );

  /// Deserializer of a JSON array of [T] without duplicates
  Deserializer<Set<T>> set() => Deserializer<Set<T>>._withMapper(
    (data, mapper) => _listOf(data, mapper).toSet(),
  );

  /// Deserializer of a JSON object whose values are [T]
  Deserializer<Map<String, T>> map() =>
      Deserializer<Map<String, T>>._withMapper((data, mapper) {
        final Map<String, dynamic> json = _asJsonObject(data);
        return {
          for (final MapEntry(:key, :value) in json.entries)
            key: _at(_keySegment(key), () => _call(value, mapper)),
        };
      });

  /// Deserializer of [T] that accepts `null`
  Deserializer<T?> nullable() => Deserializer<T?>._withMapper(
    (data, mapper) => data == null ? null : _call(data, mapper),
  );

  List<T> _listOf(Object? data, ObjectMapper mapper) {
    if (data is! List) throw _expected('an array', data);
    return [
      for (var i = 0; i < data.length; i++)
        _at('[$i]', () => _call(data[i], mapper)),
    ];
  }

  /// The deserializers registered together with this one
  List<Deserializer> _derived() {
    final nullable = this.nullable();
    final list = this.list();
    final set = this.set();
    final map = this.map();
    return [
      nullable,
      list,
      list.nullable(),
      nullable.list(),
      set,
      set.nullable(),
      map,
      map.nullable(),
      nullable.map(),
    ];
  }

  static Map<String, dynamic> _asJsonObject(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw _expected('an object', data);
  }
}

/// Converts objects to JSON and back.
///
/// - [serialize]/[deserialize] work with JSON values (`Map`, `List`, `String`, `num`, `bool`,
///   `null`), and [encode]/[decode] with JSON text.
/// - An object is serialized with its [Serializer] (or the one of a supertype), else with its
///   `toJson()`, else enums with their `name`. Maps, iterables and primitives are serialized as
///   they are, recursively.
/// - Deserialization is strict: `"12"` is not an `int`, but `12.0` is.
class ObjectMapper {
  /// `false` drops the keys with a `null` value of the objects (the maps returned by a
  /// `toJson()` or a serializer), never of a [Map] serialized directly.
  final bool includeNulls;

  /// The names of the fields of the objects in JSON: the keys of the maps returned by a
  /// `toJson()` or a serializer, and of the map given to [Deserializer.json] (with every map
  /// inside it). Never the keys of a [Map] serialized or deserialized directly.
  final FieldNaming fieldNaming;

  final DurationFormat durationFormat;

  /// Indent the JSON of [encode] (and so of the responses). Meant for development.
  final bool prettyPrint;

  final Map<Type, Serializer> _serializers = {};

  /// Serializer of a supertype found for each runtimeType (null: there is none)
  final Map<Type, Serializer?> _supertypeSerializers = {};

  final Map<Type, Deserializer> _deserializers = {};

  /// The deserializers derived from [_deserializers] (`List<T>`, `T?`...), rebuilt on every change
  final Map<Type, Deserializer> _derivedDeserializers = {};

  final Map<String, String> _dartToJsonKeys = {};
  final Map<String, String> _jsonToDartKeys = {};

  ObjectMapper({
    List<Serializer>? serializers,
    List<Deserializer>? deserializers,
    this.includeNulls = true,
    this.fieldNaming = FieldNaming.none,
    this.durationFormat = DurationFormat.milliseconds,
    this.prettyPrint = false,
  }) {
    for (final s in [..._defaultSerializers(), ...?serializers]) {
      _serializers[s.type] = s;
    }
    for (final d in [..._defaultDeserializers(), ...?deserializers]) {
      _deserializers[d.type] = d;
    }
    _rebuildDerivedDeserializers();
  }

  static List<Serializer> _defaultSerializers() => [
    Serializer<DateTime>._withMapper(
      (date, _) => date.toUtc().toIso8601String(),
    ),
    Serializer<Duration>._withMapper(
      (duration, mapper) => switch (mapper.durationFormat) {
        DurationFormat.milliseconds => duration.inMilliseconds,
        DurationFormat.iso8601 => _formatIsoDuration(duration),
      },
    ),
  ];

  static List<Deserializer> _defaultDeserializers() => [
    Deserializer<dynamic>._withMapper((data, _) => data),
    Deserializer<Object>._withMapper(
      (data, _) => data ?? (throw _expected('a value', data)),
    ),
    Deserializer<Map<dynamic, dynamic>>._withMapper(
      (data, _) => data is Map ? data : throw _expected('an object', data),
    ),
    Deserializer<String>._withMapper(
      (data, _) => data is String ? data : throw _expected('a string', data),
    ),
    Deserializer<bool>._withMapper(
      (data, _) => data is bool ? data : throw _expected('a boolean', data),
    ),
    Deserializer<num>._withMapper(
      (data, _) => data is num ? data : throw _expected('a number', data),
    ),
    Deserializer<int>._withMapper((data, _) => _asInt(data)),
    Deserializer<double>._withMapper(
      (data, _) =>
          data is num ? data.toDouble() : throw _expected('a number', data),
    ),
    Deserializer<DateTime>._withMapper((data, _) {
      if (data is! String) throw _expected('an ISO-8601 date', data);
      return DateTime.tryParse(data) ??
          (throw DeserializationException(
            'expected an ISO-8601 date, got an invalid string',
          ));
    }),
    Deserializer<Duration>._withMapper(
      (data, mapper) => switch (mapper.durationFormat) {
        DurationFormat.milliseconds => Duration(milliseconds: _asInt(data)),
        DurationFormat.iso8601 => _parseIsoDuration(data),
      },
    ),
  ];

  /// Adds a [Serializer] to the mapper (it replaces the one of the same type).
  void addSerializer<T>(Serializer<T> serializer) {
    _serializers[serializer.type] = serializer;
    _supertypeSerializers.clear();
  }

  /// Removes the [Serializer] for type [T].
  void removeSerializer<T>() {
    _serializers.remove(T);
    _supertypeSerializers.clear();
  }

  /// Adds a [Deserializer] to the mapper (it replaces the one of the same type),
  /// with its derived types (see [Deserializer]).
  void addDeserializer<T>(Deserializer<T> deserializer) {
    _deserializers[deserializer.type] = deserializer;
    _rebuildDerivedDeserializers();
  }

  /// Removes the [Deserializer] for type [T] and its derived types.
  void removeDeserializer<T>() {
    _deserializers.remove(T);
    _rebuildDerivedDeserializers();
  }

  /// The [Deserializer] registered (or derived) for [T], to build deeper types from it:
  ///
  /// ```dart
  /// om.addDeserializer(om.deserializerOf<int>().list()); // List<List<int>>, Map<String, List<int>>...
  /// ```
  Deserializer<T> deserializerOf<T>() =>
      (_deserializers[T] ??
              _derivedDeserializers[T] ??
              (throw MissingDeserializerError(T)))
          as Deserializer<T>;

  void _rebuildDerivedDeserializers() {
    _derivedDeserializers.clear();
    for (final deserializer in _deserializers.values) {
      for (final derived in deserializer._derived()) {
        _derivedDeserializers[derived.type] = derived;
      }
    }
  }

  /// [serialize] and encode the result as JSON text (indented with [prettyPrint]).
  String encode(Object? object) {
    final encoder = prettyPrint
        ? const JsonEncoder.withIndent('  ')
        : const JsonEncoder();
    return encoder.convert(serialize(object));
  }

  /// Decode the JSON text [source] and [deserialize] it.
  ///
  /// An empty [source] is `null` when [S] is nullable.
  /// Invalid JSON throws a [DeserializationFormatException] (400).
  S decode<S>(String source) {
    if (source.trim().isEmpty) {
      if (null is S) return null as S;
      throw DeserializationFormatException('The body is empty');
    }
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      throw DeserializationFormatException(
        'The body is not valid JSON',
        cause: e,
      );
    }
    return deserialize<S>(json);
  }

  /// Recursively serializes [object] to a JSON value
  /// (null, String, num, bool, List & Map with String keys).
  ///
  /// The result of `toJson()` and of the registered serializers is also serialized,
  /// so they can return maps with any serializable value (DateTime, enums, other objects...).
  ///
  /// An object that can't be serialized throws a [MissingSerializerError];
  /// a serializer or a `toJson()` that fails, a [SerializationException].
  Object? serialize(Object? object) {
    try {
      return _serialize(object);
    } on ApiException {
      rethrow;
    } on ObjectMapperException {
      rethrow;
    } on MissingSerializerError {
      rethrow;
    } catch (e) {
      throw SerializationException(e.toString());
    }
  }

  Object? _serialize(Object? object) {
    if (object == null) return null;

    final Serializer? serializer = _serializers[object.runtimeType];
    if (serializer != null) {
      return _serializeObject(serializer._call(object, this), object);
    }
    if (object is String || object is num || object is bool) return object;
    if (object is Map) {
      return <String, Object?>{
        for (final MapEntry(:key, :value) in object.entries)
          _serializeMapKey(key): _serialize(value),
      };
    }
    if (object is Iterable) return [for (final e in object) _serialize(e)];

    final Serializer? supertypeSerializer = _supertypeSerializer(object);
    if (supertypeSerializer != null) {
      return _serializeObject(supertypeSerializer._call(object, this), object);
    }

    final Object? Function()? toJson = _toJsonOf(object);
    if (toJson != null) return _serializeObject(toJson(), object);

    if (object is Enum) return object.name;

    throw MissingSerializerError(object.runtimeType);
  }

  /// The first registered serializer whose type is a supertype of [object], cached per runtimeType
  Serializer? _supertypeSerializer(Object object) {
    final Type type = object.runtimeType;
    if (_supertypeSerializers.containsKey(type)) {
      return _supertypeSerializers[type];
    }
    Serializer? found;
    for (final serializer in _serializers.values) {
      if (serializer._accepts(object)) {
        found = serializer;
        break;
      }
    }
    return _supertypeSerializers[type] = found;
  }

  /// The `toJson` method of [object], or null if it has none.
  /// It's read before calling it, so an error thrown inside `toJson` is never taken as a missing method.
  static Object? Function()? _toJsonOf(Object object) {
    try {
      final Object? toJson = (object as dynamic).toJson;
      return toJson is Object? Function() ? toJson : null;
    } on NoSuchMethodError {
      return null;
    }
  }

  /// Serialize the value returned by a serializer or a `toJson()` of [original],
  /// applying [includeNulls] and [fieldNaming] when it's an object.
  Object? _serializeObject(Object? result, Object original) {
    if (result == null ||
        result is String ||
        result is num ||
        result is bool ||
        identical(result, original)) {
      return result;
    }
    final Object? serialized = _serialize(result);
    if (serialized is! Map<String, Object?> ||
        (includeNulls && fieldNaming == FieldNaming.none)) {
      return serialized;
    }
    return {
      for (final MapEntry(:key, :value) in serialized.entries)
        if (includeNulls || value != null) _dartKeyToJson(key): value,
    };
  }

  /// JSON object keys must be Strings
  String _serializeMapKey(Object? key) {
    final serializedKey = _serialize(key);
    if (serializedKey is String) return serializedKey;
    if (serializedKey == null ||
        serializedKey is num ||
        serializedKey is bool) {
      return '$serializedKey';
    }
    throw SerializationException(
      "Map key of type ${key.runtimeType} can't be converted to a JSON key (String)",
    );
  }

  /// Deserializes the JSON value [data] (already decoded, see [decode]) into an instance of [S].
  ///
  /// Invalid data throws a [DeserializationException] (400) with the path of the value that
  /// failed (`$.items[1].name`). A type without a deserializer throws a [MissingDeserializerError]
  /// (500: it's a bug of the server, not of the client).
  S deserialize<S>(Object? data) {
    if (data is S) return data;

    final Deserializer? deserializer =
        _deserializers[S] ?? _derivedDeserializers[S];
    if (deserializer == null) throw MissingDeserializerError(S);
    return (deserializer as Deserializer<S>)._call(data, this);
  }

  String _dartKeyToJson(String key) => switch (fieldNaming) {
    FieldNaming.none => key,
    FieldNaming.snakeCase => _dartToJsonKeys[key] ??= _separateWords(key, '_'),
    FieldNaming.kebabCase => _dartToJsonKeys[key] ??= _separateWords(key, '-'),
  };

  String _jsonKeyToDart(String key) => switch (fieldNaming) {
    FieldNaming.none => key,
    FieldNaming.snakeCase => _jsonToDartKeys[key] ??= _joinWords(key, '_'),
    FieldNaming.kebabCase => _jsonToDartKeys[key] ??= _joinWords(key, '-'),
  };

  /// Renames the keys of [json] and of every map inside it to their Dart names
  Map<String, dynamic> _jsonKeysToDart(Map<String, dynamic> json) {
    if (fieldNaming == FieldNaming.none) return json;
    Object? rename(Object? data) => switch (data) {
      Map() => <String, dynamic>{
        for (final MapEntry(:key, :value) in data.entries)
          _jsonKeyToDart(key.toString()): rename(value),
      },
      List() => [for (final e in data) rename(e)],
      _ => data,
    };
    return rename(json) as Map<String, dynamic>;
  }
}

/// `userId` → `user_id`, `HTTPServer` → `http_server`
String _separateWords(String name, String separator) => name
    .replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (m) => '${m[1]}$separator${m[2]}',
    )
    .replaceAllMapped(
      RegExp('([A-Z])([A-Z][a-z])'),
      (m) => '${m[1]}$separator${m[2]}',
    )
    .toLowerCase();

/// `user_id` → `userId` (a leading separator is kept: `_id`)
String _joinWords(String name, String separator) => name.replaceAllMapped(
  RegExp('(?<=[a-zA-Z0-9])${RegExp.escape(separator)}([a-z0-9])'),
  (m) => m[1]!.toUpperCase(),
);

/// A number without decimals: `12` or `12.0`, never `"12"` nor `12.5`
int _asInt(Object? data) {
  if (data is int) return data;
  if (data is double && data.isFinite && data == data.truncateToDouble()) {
    return data.toInt();
  }
  throw _expected('an integer', data);
}

final RegExp _isoDuration = RegExp(
  r'^(-)?P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)(?:[.,](\d{1,6}))?S)?)?$',
);

/// `PT1H30M`, `-PT0.5S`, `PT0S`. Hours are not grouped into days, like `java.time.Duration`.
String _formatIsoDuration(Duration duration) {
  if (duration == Duration.zero) return 'PT0S';
  int micros = duration.inMicroseconds.abs();
  final int hours = micros ~/ Duration.microsecondsPerHour;
  micros %= Duration.microsecondsPerHour;
  final int minutes = micros ~/ Duration.microsecondsPerMinute;
  micros %= Duration.microsecondsPerMinute;
  final int seconds = micros ~/ Duration.microsecondsPerSecond;
  micros %= Duration.microsecondsPerSecond;

  final buffer = StringBuffer(duration.isNegative ? '-PT' : 'PT');
  if (hours > 0) buffer.write('${hours}H');
  if (minutes > 0) buffer.write('${minutes}M');
  if (seconds > 0 || micros > 0) {
    buffer.write(seconds);
    if (micros > 0) {
      buffer.write(
        '.${micros.toString().padLeft(6, '0').replaceFirst(RegExp(r'0+$'), '')}',
      );
    }
    buffer.write('S');
  }
  return buffer.toString();
}

/// Days (`P1DT2H`), hours, minutes and seconds with up to 6 decimals; a leading `-` is negative
Duration _parseIsoDuration(Object? data) {
  if (data is! String) throw _expected('an ISO-8601 duration', data);
  final match = _isoDuration.firstMatch(data);
  if (match == null || data.endsWith('P') || data.endsWith('T')) {
    throw DeserializationException(
      'expected an ISO-8601 duration, got an invalid string',
    );
  }
  int part(int group) => int.parse(match[group] ?? '0');
  final duration = Duration(
    days: part(2),
    hours: part(3),
    minutes: part(4),
    seconds: part(5),
    microseconds: int.parse((match[6] ?? '').padRight(6, '0')),
  );
  return match[1] == null ? duration : -duration;
}

/// Runs [body], adding [segment] to the path of the [DeserializationException] it throws
R _at<R>(String segment, R Function() body) {
  try {
    return body();
  } on DeserializationException catch (e) {
    throw e._under(segment);
  }
}

final RegExp _identifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// `.name`, or `["first name"]` when the key is not an identifier
String _keySegment(String key) =>
    _identifier.hasMatch(key) ? '.$key' : '[${jsonEncode(key)}]';

DeserializationException _expected(String what, Object? data) =>
    DeserializationException('expected $what, got ${_describe(data)}');

/// The JSON type of a value, for the messages sent to the client (never a Dart type)
String _describe(Object? data) => switch (data) {
  null => 'null',
  String() => 'a string',
  bool() => 'a boolean',
  int() => 'an integer',
  num() => 'a decimal number',
  List() => 'an array',
  Map() => 'an object',
  _ => 'an unsupported value',
};

/// No [Serializer], `toJson()` nor enum for a type: a bug of the server (500)
class MissingSerializerError extends StateError {
  final Type type;

  MissingSerializerError(this.type)
    : super(
        '$type has no toJson() and no Serializer is registered for it. '
        'Add a toJson() method or register one with '
        'om.addSerializer(Serializer<$type>((value) => ...))',
      );
}

/// No [Deserializer] for a type: a bug of the server (500)
class MissingDeserializerError extends StateError {
  final Type type;

  MissingDeserializerError(this.type)
    : super(
        'No deserializer found for type: <$type>. '
        'Register one with om.addDeserializer(Deserializer<$type>.json(...)), '
        'and deeper generic types with om.deserializerOf<T>() and '
        '.list(), .set(), .map() or .nullable()',
      );
}

class ObjectMapperException implements Exception {
  final String message;

  ObjectMapperException(this.message);

  @override
  String toString() {
    return 'ObjectMapperException{message: ${message.replaceAll('\n', '\\n')}';
  }
}

class SerializationException extends ObjectMapperException {
  SerializationException(super.message);

  @override
  String toString() {
    return 'SerializationException{message: ${message.replaceAll('\n', '\\n')}';
  }
}

/// The data can't be deserialized: a 400, whose [message] is sent to the client.
///
/// The [message] never contains Dart details: it's the [path] of the value (`$.items[1]`)
/// and the [reason] (`expected a string, got an integer`).
class DeserializationException extends ObjectMapperException {
  /// What is wrong with the value
  final String reason;

  /// Where the value is: `$` is the root, then `.field` and `[index]`.
  /// Null when the problem is not a value (an empty body, invalid JSON).
  final String? path;

  /// The original error, only for the logs (never sent to the client)
  final Object? cause;

  DeserializationException(this.reason, {this.path = r'$', this.cause})
    : super(path == null ? reason : '$path: $reason');

  /// The same exception, for a value nested under [segment]
  DeserializationException _under(String segment) => DeserializationException(
    reason,
    path: '\$$segment${path!.substring(1)}',
    cause: cause,
  );

  @override
  String toString() {
    return 'DeserializationException{message: ${message.replaceAll('\n', '\\n')}';
  }
}

/// The body is not valid JSON (or it's empty)
class DeserializationFormatException extends DeserializationException {
  DeserializationFormatException(super.reason, {super.cause})
    : super(path: null);

  @override
  String toString() {
    return 'DeserializationFormatException{message: ${message.replaceAll('\n', '\\n')}';
  }
}
