import 'dart:convert';
import 'dart:io';

/// Interface for objects that can be converted to JSON.
abstract class Serializable {
  Object? toJson();
}

const _yellowBold = '\x1B[1;33m';
const _reset = '\x1B[0m';

/// Common base for Serializers and Deserializers to handle type inference warnings.
abstract class _MapperEntity<T> {
  final Type type;

  _MapperEntity() : type = T {
    if (T == dynamic) {
      stdout.writeln(
        '\n'
        '$_yellowBold'
        'WARNING: Unable to infer type for $runtimeType. '
        'The registry was made as "dynamic", which usually happens when '
        'the generic type argument is omitted. '
        'Declare it explicitly, for example: '
        '$runtimeType<YOUR_TYPE>((value) => ...)'
        '$_reset'
        '\n',
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

  /// Helper to deserialize a list of elements using this deserializer.
  List<T> deserializeList(dynamic data) {
    if (data is List) {
      return data.map((e) => deserializer(e)).toList();
    }
    throw StateError('Cannot deserialize a List from non-list elements');
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
    Serializer<dynamic>((obj) => obj),
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
    Deserializer<dynamic>((v) => v),
    Deserializer<Object>((v) => v),
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

  /// Recursively serializes [object] to a JSON-compatible representation.
  Object? serialize(Object? object) {
    //if null => null
    if (object == null) {
      return null;
    }
    if (object is Map) {
      return object.map((k, v) => MapEntry(serialize(k), serialize(v)));
    }
    if (object is Serializable) {
      //if Serializable => serialize
      return object.toJson();
    } else if (object is List) {
      //if list, same:
      return object.map((e) {
        return serialize(e);
      }).toList();
    } else {
      Serializer? serializer =
          _serializers[_extractElementType(object.runtimeType)];
      if (serializer != null) {
        return serializer.serializer(object);
      }
    }

    throw StateError(
      '${object.runtimeType} need to implement the Serializable interface',
    );
  }

  /// Deserializes [data] into an instance of type [S].
  S deserialize<S>(dynamic data) {
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
        final List rawList = data is String ? jsonDecode(data) : (data as List);
        return elementDeserializer.deserializeList(rawList) as S;
      }
    }
    if (S.isMap) {
      throw StateError(
        '<Map> deserialization is not supported. Convert the map to a class and add the deserializer manually',
      );
      /*({Type key, Type value}) types = _extractMapElementTypes(S);

      final keyDeserializer = _deserializers[types.key];
      final valueDeserializer = _deserializers[types.value];

      if (keyDeserializer != null && valueDeserializer != null) {
        final Map rawMap = data is String ? jsonDecode(data) : (data as Map);
        //error: type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, dynamic>' in type cast
        return rawMap.map(
              (key, value) => MapEntry(
                keyDeserializer.deserializer(key),
                valueDeserializer.deserializer(value),
              ),
            )
            as S;
      }*/
    }

    throw StateError('No deserializer found for type: <$S>');
  }

  /// Extracts the element type from a List type or identifies the registered type.
  Type _extractListElementType(Type type) {
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

    // 3. Find the registered type by name matching
    return _deserializers.keys.firstWhere(
      (k) => k.toString() == typeName,
      orElse: () => _serializers.keys.firstWhere(
        (k) => k.toString() == typeName,
        orElse: () => throw StateError(
          'No serializer/deserializer found for type: <$typeName>',
        ),
      ),
    );
  }

  /// Extracts the element types from a Map type or identifies the registered type.
  ({Type key, Type value}) _extractMapElementTypes(Type type) {
    Type findType(String typeName) {
      // 3. Find the registered type by name matching
      return _deserializers.keys.firstWhere(
        (k) => k.toString() == typeName,
        orElse: () => _serializers.keys.firstWhere(
          (k) => k.toString() == typeName,
          orElse: () => throw StateError(
            'No serializer/deserializer found for type: <$typeName>',
          ),
        ),
      );
    }

    var typeName = type.toString();

    // 1. Remove nullability (T? -> T)
    if (typeName.endsWith('?')) {
      typeName = typeName.substring(0, typeName.length - 1);
    }
    List<String> types = [];

    // 2. If it's a list, extract the inner type (List<T> -> T)
    if (typeName.startsWith('Map<') && typeName.endsWith('>')) {
      typeName = typeName.substring(4, typeName.length - 1);
      types = typeName.split(',');
      // Handle nested nullability (Map<T?, T?> -> T, T)
      if (types[0].endsWith('?')) {
        types[0] = types[0].substring(0, types[0].length - 1);
      }
      if (types[1].endsWith('?')) {
        types[1] = types[1].substring(0, types[1].length - 1);
      }
    }
    return (key: findType(types[0].trim()), value: findType(types[1].trim()));
  }

  /// Extracts the element type from a List type or identifies the registered type.
  Type _extractElementType(Type type) {
    var typeName = type.toString();

    // 1. Remove nullability (T? -> T)
    if (typeName.endsWith('?')) {
      typeName = typeName.substring(0, typeName.length - 1);
    }

    // 3. Find the registered type by name matching
    return _deserializers.keys.firstWhere(
      (k) => k.toString() == typeName,
      orElse: () => _serializers.keys.firstWhere(
        (k) => k.toString() == typeName,
        orElse: () => throw StateError(
          'No serializer/deserializer found for type: <$typeName>',
        ),
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
