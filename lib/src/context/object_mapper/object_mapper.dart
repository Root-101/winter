import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:winter/winter.dart';

/// Interface for objects that can be converted to JSON.
abstract class Serializable {
  Object? toJson();
}

/// Common base for Serializers and Deserializers to handle type inference warnings.
abstract class _MapperEntity<T> {
  final Type type;

  _MapperEntity() : type = T {
    if (T == dynamic) {
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

class Serializer<T> extends _MapperEntity<T> {
  final Object? Function(dynamic object) serializer;

  Serializer(Object? Function(T object) serializer)
    : serializer = ((dynamic object) => serializer(object as T));
}

class Deserializer<T> extends _MapperEntity<T> {
  final T Function(dynamic data) deserializer;

  Deserializer(this.deserializer);

  /// Deserializer for a JSON object, [fromJson] receives the already checked map:
  ///
  /// ```dart
  /// Deserializer<User>.json(User.fromJson)
  /// ```
  ///
  /// If the data is not a JSON object, a [DeserializationException] (400) is thrown.
  ///
  /// Declare the type explicitly inside a list (`[Deserializer<User>.json(User.fromJson)]`),
  /// otherwise the type of the list wins and it's registered as `dynamic`.
  Deserializer.json(T Function(Map<String, dynamic> json) fromJson)
    : deserializer = ((dynamic data) => fromJson(_asJsonObject<T>(data)));

  static Map<String, dynamic> _asJsonObject<T>(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw DeserializationException(
      'Expected a JSON object for type <$T> but got: ${data.runtimeType}',
    );
  }

  /// Helper to deserialize a list of elements using this deserializer.
  List<T> deserializeList(dynamic data) {
    if (data is List) {
      return data.map((e) => deserializer(e)).toList();
    }
    throw StateError('Cannot deserialize a List from non-list elements');
  }

  /// Helper to deserialize the values of a JSON object using this deserializer.
  Map<String, T> deserializeMap(Map data) {
    return data.map((k, v) => MapEntry(k.toString(), deserializer(v)));
  }
}

class ObjectMapper {
  static final List<Serializer> _defaultSerializers = [
    Serializer<DateTime>((obj) => obj.toIso8601String()),
    Serializer<Duration>((obj) => obj.inMilliseconds),
    Serializer<String>((obj) => obj),
    Serializer<num>((obj) => obj),
    Serializer<int>((obj) => obj),
    Serializer<double>((obj) => obj),
    Serializer<bool>((obj) => obj),
    //Serializer<dynamic>((obj) => obj),
    Serializer<Object>((obj) => obj),
  ];

  static final List<Deserializer> _defaultDeserializers = [
    Deserializer<DateTime>((v) => DateTime.parse(v.toString())),
    Deserializer<Duration>(
      (v) => Duration(milliseconds: int.parse(v.toString())),
    ),
    Deserializer<String>((v) => v as String),
    Deserializer<num>((v) => num.parse(v.toString())),
    Deserializer<int>((v) => int.parse(v.toString())),
    Deserializer<double>((v) => double.parse(v.toString())),
    Deserializer<bool>((v) => bool.parse(v.toString())),
    //Deserializer<dynamic>((v) => v),
    Deserializer<Object>((v) => v as Object),
  ];

  final Map<Type, Serializer> _serializers = {};
  final Map<Type, Deserializer> _deserializers = {};

  ObjectMapper({
    List<Serializer>? serializers,
    List<Deserializer>? deserializers,
  }) {
    _registerDefaults();
    if (serializers != null) {
      for (var s in serializers) {
        _serializers[s.type] = s;
      }
    }
    if (deserializers != null) {
      for (var d in deserializers) {
        _deserializers[d.type] = d;
      }
    }
  }

  void _registerDefaults() {
    for (var s in _defaultSerializers) {
      _serializers[s.type] = s;
    }
    for (var d in _defaultDeserializers) {
      _deserializers[d.type] = d;
    }
  }

  /// Adds a [Serializer] to the mapper.
  void addSerializer<T>(Serializer<T> serializer) {
    _serializers[T] = serializer;
  }

  /// Removes the [Serializer] for type [T].
  void removeSerializer<T>() {
    _serializers.remove(T);
  }

  /// Adds a [Deserializer] to the mapper.
  void addDeserializer<T>(Deserializer<T> deserializer) {
    _deserializers[T] = deserializer;
  }

  /// Removes the [Deserializer] for type [T].
  void removeDeserializer<T>() {
    _deserializers.remove(T);
  }

  /// Recursively serializes [object] to a JSON-compatible representation
  /// (null, String, num, bool, List & Map with String keys).
  ///
  /// The result of [Serializable.toJson] and of the registered serializers is also serialized,
  /// so they can return maps with any serializable value (DateTime, enums, other objects...).
  Object? serialize(Object? object) {
    try {
      //if null => null
      if (object == null) {
        return null;
      }
      if (object is Map) {
        return object.map(
          (k, v) => MapEntry(_serializeMapKey(k), serialize(v)),
        );
      }
      if (object is Serializable) {
        //if Serializable => serialize (and its result too)
        return _serializeResult(object.toJson(), object);
      }
      if (object is Iterable) {
        //List, Set... => List
        return object.map(serialize).toList();
      }

      Serializer? serializer = _serializers[object.runtimeType];
      if (serializer != null) {
        return _serializeResult(serializer.serializer(object), object);
      }

      //Enums without a custom serializer => its name
      if (object is Enum) {
        return object.name;
      }

      throw StateError(
        '${object.runtimeType} need to implement the Serializable interface',
      );
    } on ApiException {
      rethrow;
    } on ObjectMapperException {
      rethrow;
    } on StateError {
      rethrow;
    } on Exception catch (e) {
      throw SerializationException(e.toString());
    } on Error catch (e) {
      throw SerializationException(e.toString());
    }
  }

  /// Serialize the value returned by a serializer or a `toJson`.
  /// A primitive (or the same object, like the default serializers do) is already JSON-compatible.
  Object? _serializeResult(Object? result, Object original) {
    if (result == null ||
        result is String ||
        result is num ||
        result is bool ||
        identical(result, original)) {
      return result;
    }
    return serialize(result);
  }

  /// JSON object keys must be Strings
  String _serializeMapKey(Object? key) {
    final serializedKey = serialize(key);
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

  /// Deserializes [data] into an instance of type [S].
  S deserialize<S>(dynamic data) {
    try {
      if (data is S) return data;

      final deserializer = _deserializers[S];
      if (deserializer != null) {
        final targetData = (data is String && !_isPrimitive(S))
            ? jsonDecode(data)
            : data;
        return (deserializer as Deserializer<S>).deserializer(targetData);
      }

      if (S.isList) {
        final elementType = _extractListElementType(S);
        final elementDeserializer = _deserializers[elementType];

        if (elementDeserializer != null) {
          final List rawList =
              (data is String ? jsonDecode(data) : data) as List;
          return elementDeserializer.deserializeList(rawList) as S;
        }
      }
      if (S.isMap) {
        final Object? rawMap = data is String ? jsonDecode(data) : data;
        if (rawMap is! Map) {
          throw DeserializationException(
            'Expected a JSON object for type <$S> but got: ${rawMap.runtimeType}',
          );
        }

        ///Map<String, dynamic>, Map<String, Object?>, Map...
        if (rawMap is S) return rawMap as S;
        final Map<String, dynamic> jsonMap = rawMap.map(
          (k, v) => MapEntry(k.toString(), v),
        );
        if (jsonMap is S) return jsonMap as S;

        ///Map<String, T>: use the deserializer of T for every value
        final Type valueType = _extractMapValueType(S);
        return _deserializers[valueType]!.deserializeMap(rawMap) as S;
      }

      throw StateError('No deserializer found for type: <$S>');
    } on ApiException {
      rethrow;
    } on ObjectMapperException {
      rethrow;
    } on StateError {
      rethrow;
    } on FormatException catch (e) {
      throw DeserializationFormatException(
        e.toString().replaceAll('FormatException:', '').trim(),
      );
    } on Exception catch (e) {
      throw DeserializationException(e.toString());
    } on Error catch (e) {
      throw DeserializationException(e.toString());
    }
  }

  /// Extracts the element type from a List type or identifies the registered type.
  Type? _extractListElementType(Type type) {
    var typeName = type.toString();

    // 1. Remove nullability (T? -> T)
    if (typeName.endsWith('?')) {
      typeName = typeName.substring(0, typeName.length - 1);
    }

    // 2. If it's a list, extract the inner type (List<T> -> T)
    if (typeName.startsWith('List<') && typeName.endsWith('>')) {
      typeName = typeName.substring(5, typeName.length - 1);
      // Handle nested nullability (List<T?> -> T)
      if (typeName.endsWith('?')) {
        typeName = typeName.substring(0, typeName.length - 1);
      }
    }

    // 3. Find the registered type by name matching (null if there is no deserializer)
    return _deserializers.keys.firstWhereOrNull(
      (k) => k.toString() == typeName,
    );
  }

  /// Extracts the value type from a Map type (`Map<String, T>` -> `T`) and finds its registered deserializer type.
  /// Only String keys are supported, since JSON object keys are always strings.
  Type _extractMapValueType(Type type) {
    var typeName = type.toString();

    // 1. Remove nullability (Map<K, V>? -> Map<K, V>)
    if (typeName.endsWith('?')) {
      typeName = typeName.substring(0, typeName.length - 1);
    }

    // 2. Split 'K, V' by the first comma outside of generics (V can be generic: Map<String, Map<String, int>>)
    final inner = typeName.substring(4, typeName.length - 1);
    int depth = 0;
    int splitIndex = -1;
    for (int i = 0; i < inner.length && splitIndex < 0; i++) {
      if (inner[i] == '<') depth++;
      if (inner[i] == '>') depth--;
      if (inner[i] == ',' && depth == 0) splitIndex = i;
    }
    final keyTypeName = inner.substring(0, splitIndex).trim();
    var valueTypeName = inner.substring(splitIndex + 1).trim();

    if (keyTypeName != 'String') {
      throw StateError(
        'Only Map<String, T> deserialization is supported (JSON keys are always String), found: <$type>',
      );
    }

    // 3. Remove value nullability (T? -> T)
    if (valueTypeName.endsWith('?')) {
      valueTypeName = valueTypeName.substring(0, valueTypeName.length - 1);
    }

    // 4. Find the registered type by name matching
    return _deserializers.keys.firstWhere(
      (k) => k.toString() == valueTypeName,
      orElse: () => throw StateError(
        'No deserializer found for the values of type: <$type>',
      ),
    );
  }

  bool _isPrimitive(Type type) {
    return _defaultDeserializers.any((element) => element.type == type);
  }
}

extension ListTypeExtension on Type {
  bool get isList =>
      toString().startsWith('List<') &&
      (toString().endsWith('>') || toString().endsWith('>?'));

  bool get isMap =>
      toString().startsWith('Map<') &&
      (toString().endsWith('>') || toString().endsWith('>?'));
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

class DeserializationException extends ObjectMapperException {
  DeserializationException(super.message);

  @override
  String toString() {
    return 'DeserializationException{message: ${message.replaceAll('\n', '\\n')}';
  }
}

class DeserializationFormatException extends DeserializationException {
  DeserializationFormatException(super.message);

  @override
  String toString() {
    return 'DeserializationFormatException{message: ${message.replaceAll('\n', '\\n')}';
  }
}
