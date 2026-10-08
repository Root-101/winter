import 'dart:convert';

import 'package:winter/winter.dart';

/// How the field names of the objects are written in JSON, see [ObjectMapper.fieldNaming]
///
/// {@category Object mapper}
enum FieldNaming {
  /// As the model writes them (`userId`)
  none,

  /// `user_id`
  snakeCase,

  /// `user-id`
  kebabCase,
}

/// How a [Duration] is written in JSON, see [ObjectMapper.durationFormat]
///
/// {@category Object mapper}
enum DurationFormat {
  /// An integer: `5400000`
  milliseconds,

  /// ISO-8601: `PT1H30M`
  iso8601,
}

/// Common base for Serializers and Deserializers: the type they are registered with.
abstract class _MapperEntity<T> {
  final Type type;

  /// An [ArgumentError] when the type is `dynamic` or `Enum`: inside a list (`deserializers: [...]`)
  /// Dart infers the type from the list, not from the arguments, and the mapper would register it
  /// for the wrong type (a 500 on the first request). Failing here shows it at start.
  _MapperEntity({bool checkType = true}) : type = T {
    if (checkType && (T == dynamic || T == Enum)) {
      final String kind = runtimeType.toString().split('<').first;
      throw ArgumentError(
        'A $kind needs its type: it was inferred as <$T>, which happens when the type argument '
        'is left out inside a list. Declare it: '
        '${kind == 'Serializer' ? 'Serializer<Money>((money) => ...)' : 'Deserializer<User>.json(User.fromJson)'}',
      );
    }
  }
}

/// Converts a [T] into a JSON value. It also applies to the subtypes of [T]
/// (when they have no serializer of their own), so it works with `freezed` and sealed classes.
///
/// The result is serialized again, so it can return maps with any serializable value.
///
/// {@category Object mapper}
class Serializer<T> extends _MapperEntity<T> {
  final Object? Function(T object, ObjectMapper mapper) _serialize;

  /// [serializer] converts a [T] (or a subtype) into a JSON value; what it returns is serialized
  /// again. If it throws, the response is a 500 ([SerializationException]).
  Serializer(Object? Function(T object) serializer)
    : _serialize = ((object, _) => serializer(object));

  Serializer._withMapper(this._serialize) : super(checkType: false);

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
///
/// {@category Object mapper}
class Deserializer<T> extends _MapperEntity<T> {
  final T Function(Object? data, ObjectMapper mapper) _deserialize;

  /// [deserializer] receives the decoded JSON value. If it throws, the client gets a 400
  /// (`invalid value`, without the type: it would expose the name of a class of the server, obfuscated or not) and the original error is logged at debug.
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

  /// Deserializer of a type written as a JSON string:
  ///
  /// ```dart
  /// Deserializer<Uri>.string(Uri.parse)
  /// ```
  ///
  /// Any other JSON value is a 400 that says so (`$.url: expected a string, got an integer`);
  /// if [fromString] throws, a 400 `invalid value`.
  Deserializer.string(T Function(String value) fromString)
    : _deserialize = ((data, _) => fromString(
        data is String ? data : throw _expected('a string', data),
      ));

  /// Deserializer of a type written as a JSON integer (`12`, or `12.0`), see [Deserializer.string]
  Deserializer.integer(T Function(int value) fromInt)
    : _deserialize = ((data, _) => fromInt(_asInt(data)));

  /// Deserializer of a type written as a JSON number, see [Deserializer.string]
  Deserializer.number(T Function(num value) fromNumber)
    : _deserialize = ((data, _) =>
          fromNumber(data is num ? data : throw _expected('a number', data)));

  /// Deserializer of a type written as a JSON boolean, see [Deserializer.string]
  Deserializer.boolean(T Function(bool value) fromBool)
    : _deserialize = ((data, _) =>
          fromBool(data is bool ? data : throw _expected('a boolean', data)));

  Deserializer._withMapper(this._deserialize) : super(checkType: false);

  /// Deserializer of an enum written as its `name`, the way enums are serialized by default:
  ///
  /// ```dart
  /// Deserializer<Status>.enumByName(Status.values)
  /// ```
  ///
  /// Any other value is a 400 that lists the valid names
  /// (`$.status: expected one of pending, paid, got another string`).
  /// An enum with its own `toJson()` needs its own deserializer. [values] must be the values of
  /// an enum ([ArgumentError] otherwise), and the type is always written, like for the other
  /// constructors.
  factory Deserializer.enumByName(List<T> values) {
    if (T == dynamic || T == Enum) {
      throw ArgumentError(
        'A Deserializer needs its type: it was inferred as <$T>. '
        'Declare it: Deserializer<Status>.enumByName(Status.values)',
      );
    }
    if (values.isEmpty || values.first is! Enum) {
      throw ArgumentError.value(values, 'values', 'The values of an enum');
    }
    final Map<String, T> byName = {
      for (final value in values) (value as Enum).name: value,
    };
    final String names = byName.keys.join(', ');
    return Deserializer<T>._withMapper((data, _) {
      if (data is! String) throw _expected('one of $names', data);
      return byName[data] ??
          (throw DeserializationException(
            'expected one of $names, got another string',
          ));
    });
  }

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
      ///Never the message of the error: it may contain the value sent (personal data)
      if (logger.isEnabled(LogLevel.debug)) {
        logger.debug('Invalid value for <$T> (${e.runtimeType})');
      }
      throw DeserializationException('invalid value', cause: e);
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

  /// Deserializer of a JSON object whose values are [T] and whose keys are a [K], read from their
  /// text: `int`, `double`, `num` and `bool` are parsed, and any other [K] goes through its own
  /// deserializer with the key as a string (an enum with [Deserializer.enumByName], `DateTime`, a
  /// [Deserializer.string]). It's what the mapper writes for those keys, so they round-trip:
  ///
  /// ```dart
  /// om.addDeserializer(om.deserializerOf<Price>().mapWithKeys<int>());  // Map<int, Price>
  /// om.addDeserializer(om.deserializerOf<int>().mapWithKeys<Status>()); // Map<Status, int>
  /// ```
  ///
  /// A key that isn't a [K] is a 400 at its path (`$["abc"]: expected an integer as the key`).
  Deserializer<Map<K, T>> mapWithKeys<K>() =>
      Deserializer<Map<K, T>>._withMapper((data, mapper) {
        final Map<String, dynamic> json = _asJsonObject(data);
        return {
          for (final MapEntry(:key, :value) in json.entries)
            _at(_keySegment(key), () => mapper._mapKey<K>(key)): _at(
              _keySegment(key),
              () => _call(value, mapper),
            ),
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

/// The types that the app registered in [previous] (a serializer or a deserializer) and [next] has
/// none of: what replacing [previous] with [next] loses. Internal: `WinterContext.setUp` warns
/// with them.
List<Type> lostRegistrations(ObjectMapper previous, ObjectMapper next) => {
  for (final Type type in previous._appSerializers)
    if (!next._serializers.containsKey(type)) type,
  for (final Type type in previous._appDeserializers)
    if (!next._deserializers.containsKey(type)) type,
}.toList();

/// The [Serializer] and the [Deserializer] of a type, in one: for a type you don't own (`Uri`,
/// a class of another package) that is written as a JSON string, number or object.
///
/// ```dart
/// ObjectMapper(adapters: [
///   JsonAdapter<Uri>.string(toJson: (uri) => uri.toString(), fromJson: Uri.parse),
///   JsonAdapter<Money>.json(toJson: (money) => money.toMap(), fromJson: Money.fromMap),
/// ])
/// ```
///
/// Declare its type (`JsonAdapter<Uri>`): inside a list, Dart would infer `dynamic`, and that is
/// an [ArgumentError].
///
/// {@category Object mapper}
final class JsonAdapter<T> {
  /// How a [T] is written
  final Serializer<T> serializer;

  /// How a [T] is read
  final Deserializer<T> deserializer;

  /// An adapter from a [Serializer] and a [Deserializer] of the same type
  JsonAdapter(this.serializer, this.deserializer);

  /// A [T] written as any JSON value: [fromJson] receives the decoded value
  JsonAdapter.value({
    required Object? Function(T value) toJson,
    required T Function(dynamic json) fromJson,
  }) : this(Serializer<T>(toJson), Deserializer<T>(fromJson));

  /// A [T] written as a JSON string (`Uri`, a `BigInt`, an id); another JSON value is a 400
  JsonAdapter.string({
    required String Function(T value) toJson,
    required T Function(String json) fromJson,
  }) : this(Serializer<T>(toJson), Deserializer<T>.string(fromJson));

  /// A [T] written as a JSON integer; another JSON value is a 400
  JsonAdapter.integer({
    required int Function(T value) toJson,
    required T Function(int json) fromJson,
  }) : this(Serializer<T>(toJson), Deserializer<T>.integer(fromJson));

  /// A [T] written as a JSON number; another JSON value is a 400
  JsonAdapter.number({
    required num Function(T value) toJson,
    required T Function(num json) fromJson,
  }) : this(Serializer<T>(toJson), Deserializer<T>.number(fromJson));

  /// A [T] written as a JSON object: its keys follow [ObjectMapper.fieldNaming] both ways
  JsonAdapter.json({
    required Map<String, Object?> Function(T value) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
  }) : this(Serializer<T>(toJson), Deserializer<T>.json(fromJson));
}

/// Converts objects to JSON and back.
///
/// - [serialize]/[deserialize] work with JSON values (`Map`, `List`, `String`, `num`, `bool`,
///   `null`), and [encode]/[decode] with JSON text.
/// - An object is serialized with its [Serializer] (or the one of a supertype), else with its
///   `toJson()`, else enums with their `name`. Maps, iterables and primitives are serialized as
///   they are, recursively.
/// - Deserialization is strict: `"12"` is not an `int`, but `12.0` is.
///
/// ```dart
/// Winter.context.setUp(
///   objectMapper: ObjectMapper(fieldNaming: FieldNaming.snakeCase)
///     ..addDeserializer(Deserializer<User>.json(User.fromJson)),
/// );
///
/// final User user = await request.body<User>(); // a 400 with the path of a wrong value
/// return ResponseEntity.ok(body: user);          // written with its toJson()
/// ```
///
/// {@category Object mapper}
class ObjectMapper {
  /// `false` drops the keys with a `null` value of the objects (the maps returned by a
  /// `toJson()` or a serializer), never of a [Map] serialized directly.
  final bool includeNulls;

  /// The names of the fields of the objects in JSON: the keys of the maps returned by a
  /// `toJson()` or a serializer, and of the map given to [Deserializer.json] (with every map
  /// inside it). Never the keys of a [Map] serialized or deserialized directly.
  final FieldNaming fieldNaming;

  /// How a [Duration] is written and read: milliseconds (default) or ISO-8601.
  final DurationFormat durationFormat;

  /// Indent the JSON of [encode] (and so of the responses), on by default so they are easy to
  /// read. `false` writes compact JSON, for smaller responses.
  final bool prettyPrint;

  final Map<Type, Serializer> _serializers = {};

  /// How each runtimeType is converted (serializer, `toJson()`, enum...), found once per type
  final Map<Type, Object? Function(Object object)> _converters = {};

  final Map<Type, Deserializer> _deserializers = {};

  /// The deserializers derived from [_deserializers] (`List<T>`, `T?`...), rebuilt on every change
  final Map<Type, Deserializer> _derivedDeserializers = {};

  final Map<String, String> _dartToJsonKeys = {};
  final Map<String, String> _jsonToDartKeys = {};

  /// A mapper with the default serializers and deserializers (`DateTime`, `Duration`, primitives),
  /// plus [serializers], [deserializers] and [adapters] (which replace a default of the same type).
  ObjectMapper({
    List<Serializer>? serializers,
    List<Deserializer>? deserializers,
    List<JsonAdapter>? adapters,
    this.includeNulls = true,
    this.fieldNaming = FieldNaming.none,
    this.durationFormat = DurationFormat.milliseconds,
    this.prettyPrint = true,
  }) {
    for (final s in _defaultSerializers()) {
      _serializers[s.type] = s;
    }
    for (final s in [
      ...?serializers,
      ...?adapters?.map((adapter) => adapter.serializer),
    ]) {
      _serializers[s.type] = s;
      _appSerializers.add(s.type);
    }
    for (final d in _defaultDeserializers()) {
      _deserializers[d.type] = d;
    }
    for (final d in [
      ...?deserializers,
      ...?adapters?.map((adapter) => adapter.deserializer),
    ]) {
      _deserializers[d.type] = d;
      _appDeserializers.add(d.type);
    }
    _rebuildDerivedDeserializers();
  }

  /// The types with a serializer (or a deserializer) of the app, not a default one: what is lost
  /// when the mapper is replaced (see [lostRegistrations])
  final Set<Type> _appSerializers = {};
  final Set<Type> _appDeserializers = {};

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
    _appSerializers.add(serializer.type);
    _converters.clear();
  }

  /// Removes the [Serializer] for type [T].
  void removeSerializer<T>() {
    _serializers.remove(T);
    _appSerializers.remove(T);
    _converters.clear();
  }

  /// Adds a [Deserializer] to the mapper (it replaces the one of the same type),
  /// with its derived types (see [Deserializer]).
  void addDeserializer<T>(Deserializer<T> deserializer) {
    _deserializers[deserializer.type] = deserializer;
    _appDeserializers.add(deserializer.type);
    _rebuildDerivedDeserializers();
  }

  /// Adds the [Serializer] and the [Deserializer] of a [JsonAdapter] (they replace those of the
  /// same type)
  void addAdapter<T>(JsonAdapter<T> adapter) {
    addSerializer<T>(adapter.serializer);
    addDeserializer<T>(adapter.deserializer);
  }

  /// Removes the [Deserializer] for type [T] and its derived types.
  void removeDeserializer<T>() {
    _deserializers.remove(T);
    _appDeserializers.remove(T);
    _rebuildDerivedDeserializers();
  }

  /// A key of a JSON object as a [K] (see [Deserializer.mapWithKeys])
  K _mapKey<K>(String key) {
    final Object? value = switch (K) {
      const (String) => key,
      const (int) => int.tryParse(key) ?? (throw _keyIsNot('an integer')),
      const (double) => double.tryParse(key) ?? (throw _keyIsNot('a number')),
      const (num) => num.tryParse(key) ?? (throw _keyIsNot('a number')),
      const (bool) => switch (key) {
        'true' => true,
        'false' => false,
        _ => throw _keyIsNot('true or false'),
      },
      _ => deserializerOf<K>()._call(key, this),
    };
    return value as K;
  }

  static DeserializationException _keyIsNot(String what) =>
      DeserializationException('expected $what as the key');

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

  /// Encodes [object] as JSON text (indented with [prettyPrint]), in a single pass.
  ///
  /// Same result as `jsonEncode(serialize(object))`, but maps, lists and primitives are written
  /// directly by the [JsonEncoder]: only the objects are converted (see [serialize]).
  String encode(Object? object) {
    try {
      return (prettyPrint ? _prettyEncoder : _encoder).convert(object);
    } on JsonUnsupportedObjectError catch (e) {
      throw _serializationError(e.cause ?? e);
    }
  }

  late final JsonEncoder _encoder = JsonEncoder(_encodable);
  late final JsonEncoder _prettyEncoder = JsonEncoder.withIndent(
    '  ',
    _encodable,
  );

  /// For the [JsonEncoder]: errors thrown here are wrapped in a [JsonUnsupportedObjectError]
  Object? _encodable(Object? object) => _toEncodable(object!);

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
  /// Primitives, lists and maps are kept as they are (map keys converted to String, any other
  /// [Iterable] to a list). Any other object is converted with, in order: the [Serializer] of its
  /// exact type, the first [Serializer] of a supertype, its `toJson()`, or its `name` (enums).
  /// The result of a serializer or a `toJson()` is serialized again, so they can return maps with
  /// any serializable value (DateTime, enums, other objects...).
  ///
  /// An object that can't be serialized throws a [MissingSerializerError];
  /// a serializer or a `toJson()` that fails, a [SerializationException].
  Object? serialize(Object? object) {
    try {
      return _serialize(object);
    } catch (e) {
      throw _serializationError(e);
    }
  }

  /// [ApiException]s, mapper errors and [MissingSerializerError] as they are, anything else
  /// (an error inside a `toJson()`, a cycle...) as a [SerializationException]
  static Object _serializationError(Object error) => switch (error) {
    ApiException() ||
    ObjectMapperException() ||
    MissingSerializerError() => error,
    _ => SerializationException(error.toString()),
  };

  Object? _serialize(Object? object) {
    if (object == null || object is String || object is num || object is bool) {
      return object;
    }
    if (object is List) return [for (final e in object) _serialize(e)];
    if (object is Map) {
      return <String, Object?>{
        for (final MapEntry(:key, :value) in object.entries)
          _serializeMapKey(key): _serialize(value),
      };
    }
    final Object? converted = _toEncodable(object);
    if (identical(converted, object)) {
      throw SerializationException(
        'The serializer of ${object.runtimeType} returned the same object',
      );
    }
    return _serialize(converted);
  }

  /// Converts one level of an object that is not a JSON value: the [JsonEncoder] (or
  /// [_serialize]) converts what is inside the result. Lists, maps with String keys and
  /// primitives never get here when encoding, the [JsonEncoder] writes them itself.
  Object? _toEncodable(Object object) {
    if (object is Map) {
      return <String, Object?>{
        for (final MapEntry(:key, :value) in object.entries)
          _serializeMapKey(key): value,
      };
    }
    if (object is Iterable) return object.toList();

    return (_converters[object.runtimeType] ??= _converterOf(object))(object);
  }

  /// How to convert the objects with the runtimeType of [object]
  Object? Function(Object object) _converterOf(Object object) {
    final Serializer? serializer =
        _serializers[object.runtimeType] ?? _supertypeSerializer(object);
    if (serializer != null) {
      return (object) => _applyObjectOptions(serializer._call(object, this));
    }

    ///The error format of Winter has fixed names (`requestId`, `fieldName`), whatever the
    ///[fieldNaming] of the app: a client reads the errors of every Winter app the same way
    if (object is ProblemDetails) {
      return (object) => (object as ProblemDetails).toJson();
    }
    if (object is ConstraintViolation) {
      return (object) => (object as ConstraintViolation).toJson();
    }
    if (_hasToJson(object)) {
      return (object) => _applyObjectOptions((object as dynamic).toJson());
    }
    if (object is Enum) return (object) => (object as Enum).name;

    final Type type = object.runtimeType;
    return (_) => throw MissingSerializerError(type);
  }

  /// The first registered serializer whose type is a supertype of [object]
  Serializer? _supertypeSerializer(Object object) {
    for (final serializer in _serializers.values) {
      if (serializer._accepts(object)) return serializer;
    }
    return null;
  }

  /// Whether [object] has a `toJson()` method that takes no arguments.
  /// It's read as a tear-off without calling it, so an error thrown inside a `toJson()` is never
  /// taken as a missing method.
  static bool _hasToJson(Object object) {
    try {
      return (object as dynamic).toJson is Object? Function();
    } on NoSuchMethodError {
      return false;
    }
  }

  /// [includeNulls] and [fieldNaming] on the result of a serializer or a `toJson()`, when it's an object
  Object? _applyObjectOptions(Object? result) {
    if (result is! Map || (includeNulls && fieldNaming == FieldNaming.none)) {
      return result;
    }
    return <String, Object?>{
      for (final MapEntry(:key, :value) in result.entries)
        if (includeNulls || value != null)
          _dartKeyToJson(_serializeMapKey(key)): value,
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

  /// The name of a field (or a path: `items[0].firstName`) in JSON, following [fieldNaming]:
  /// `items[0].first_name` with `snakeCase`. Used for the `fieldName` of the 422, so it's the
  /// name the client sent. A quoted key of a map (`prices["eurPrice"]`) is data: never renamed.
  String jsonFieldName(String name) => fieldNaming == FieldNaming.none
      ? name
      : name.replaceAllMapped(
          _nameInPath,
          (m) => m[1] ?? _dartKeyToJson(m[0]!),
        );

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

/// Each name of a field path (`items[0].firstName`: `items` and `firstName`, not the index)
/// A quoted key of a map (`["eur"]`, kept as it is in group 1) or a name of a field
final RegExp _nameInPath = RegExp(
  r'(\["(?:[^"\\]|\\.)*"\])|[a-zA-Z_][a-zA-Z0-9_]*',
);

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
///
/// {@category Object mapper}
class MissingSerializerError extends StateError {
  /// The type of the object that couldn't be serialized
  final Type type;

  /// [type] has no serializer, `toJson()` nor enum `name`
  MissingSerializerError(this.type)
    : super(
        '$type has no toJson() without parameters and no Serializer is registered '
        'for it. Add a toJson() method or register one with '
        'om.addSerializer(Serializer<$type>((value) => ...))',
      );
}

/// No [Deserializer] for a type: a bug of the server (500)
///
/// {@category Object mapper}
class MissingDeserializerError extends StateError {
  /// The type that was asked for
  final Type type;

  /// No deserializer registered nor derived for [type]
  MissingDeserializerError(this.type)
    : super(
        'No deserializer found for type: <$type>. '
        'Register one with om.addDeserializer(Deserializer<$type>.json(...)), '
        'and deeper generic types with om.deserializerOf<T>() and '
        '.list(), .set(), .map() or .nullable()',
      );
}

/// Base of the errors of the [ObjectMapper] that are [Exception]s (a bad value, not a bug)
///
/// {@category Object mapper}
class ObjectMapperException implements Exception {
  /// What went wrong
  final String message;

  /// An error of the mapper, described by [message]
  ObjectMapperException(this.message);

  @override
  String toString() {
    return 'ObjectMapperException{message: ${message.replaceAll('\n', '\\n')}';
  }
}

/// A serializer or a `toJson()` failed: a 500, its [message] is only logged
///
/// {@category Object mapper}
class SerializationException extends ObjectMapperException {
  /// A failed serialization, described by [message]
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
///
/// {@category Object mapper}
class DeserializationException extends ObjectMapperException {
  /// What is wrong with the value
  final String reason;

  /// Where the value is: `$` is the root, then `.field` and `[index]`.
  /// Null when the problem is not a value (an empty body, invalid JSON).
  final String? path;

  /// The original error, only for the logs (never sent to the client)
  final Object? cause;

  /// [reason] of the value at [path] (`$` by default: the root), with the original error as [cause]
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
///
/// {@category Object mapper}
class DeserializationFormatException extends DeserializationException {
  /// The body is not valid JSON or it's empty ([reason]), with the parser error as [cause]
  DeserializationFormatException(super.reason, {super.cause})
    : super(path: null);

  @override
  String toString() {
    return 'DeserializationFormatException{message: ${message.replaceAll('\n', '\\n')}';
  }
}
