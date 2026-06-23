import 'dart:convert';
import 'dart:io';

abstract class Serializable {
  Object? toJson();
}

const yellowBold = '\x1B[1;33m';
const reset = '\x1B[0m';

class Serializer<T> {
  final Type type;
  final Object? Function(dynamic object) serializer;

  Serializer(Object? Function(T object) serializer)
    : type = T,
      serializer = ((dynamic object) => serializer(object as T)) {
    if (type.toString() == 'dynamic') {
      stdout.writeln(
        '\n'
        '$yellowBold'
        'WARNING: Unable to infer Serializer type. '
        'The serializer was registered as "dynamic", which usually happens when '
        'the generic type argument is omitted. '
        'Declare it explicitly, for example: '
        'Serializer<YOUR-EXPLICIT-TYPE>((object) => object.toJson())'
        '$reset'
        '\n',
      );
    }
  }
}

class Deserializer<T> {
  final Type type;
  final T Function(dynamic data) deserializer;
  final List<T> Function(dynamic data) listDeserializer;

  Deserializer(this.deserializer)
    : type = T,
      listDeserializer = ((dynamic data) {
        if (data is List) {
          return data.map((e) => deserializer(e)).toList();
        }
        throw StateError('Can\'t deserialize a List that is not a list');
      }) {
    if (type.toString() == 'dynamic') {
      stdout.writeln(
        '\n'
        '$yellowBold'
        'WARNING: Unable to infer Deserializer type. '
        'The deserializer was registered as "dynamic", which usually happens when '
        'the generic type argument is omitted. '
        'Declare it explicitly, for example: '
        'Deserializer<YOUR-EXPLICIT-TYPE>((object) => object.toJson())'
        '$reset'
        '\n',
      );
    }
  }
}

class ObjectMapper {
  static final List<Serializer> _defaultSerializers = [
    Serializer<DateTime>((object) => object.toIso8601String()),
    Serializer<Duration>((object) => object.inMilliseconds),
    Serializer<Uri>((object) => object.toString()),
    Serializer<RegExp>((object) => object.pattern),
    Serializer<String>((object) => object),
    Serializer<num>((object) => object),
    Serializer<int>((object) => object),
    Serializer<double>((object) => object),
    Serializer<bool>((object) => object),
  ];

  static final List<Deserializer> _defaultDeserializers = [
    Deserializer<DateTime>((value) => DateTime.parse(value.toString())),
    Deserializer<Duration>(
      (value) => Duration(milliseconds: int.parse(value.toString())),
    ),
    Deserializer<Uri>((value) => Uri.parse(value.toString())),
    Deserializer<RegExp>((value) => RegExp(value.toString())),
    Deserializer<String>((value) => value as String),
    Deserializer<num>((value) => num.parse(value.toString())),
    Deserializer<int>((value) => int.parse(value.toString())),
    Deserializer<double>((value) => double.parse(value.toString())),
    Deserializer<bool>((value) => bool.parse(value.toString())),
  ];

  final Map<Type, Serializer> _serializers = {};
  final Map<Type, Deserializer> _deserializers = {};

  ObjectMapper({
    List<Serializer>? serializers,
    List<Deserializer>? deserializers,
  }) {
    _serializers.addAll(
      Map.fromEntries(_defaultSerializers.map((e) => MapEntry(e.type, e))),
    );
    _deserializers.addAll(
      Map.fromEntries(_defaultDeserializers.map((e) => MapEntry(e.type, e))),
    );

    if (serializers != null) {
      _serializers.addAll(
        Map.fromEntries(serializers.map((e) => MapEntry(e.type, e))),
      );
    }
    if (deserializers != null) {
      _deserializers.addAll(
        Map.fromEntries(deserializers.map((e) => MapEntry(e.type, e))),
      );
    }
  }

  Object? serialize<S>(S object) {
    //if null => null
    if (object == null) {
      return null;
    }
    if (object is Map) {
      return object;
    }
    if (object is Serializable) {
      //if Serializable => serialize
      return object.toJson();
    } else if (object is List) {
      //if list, same:
      return object.map((e) {
        if (e is Map) {
          return e;
        }

        if (e is Serializable) {
          //if element is Serializable => serialize
          return e.toJson();
        } else {
          Serializer? serializer = _serializers[e.runtimeType];
          if (serializer != null) {
            return serializer.serializer(e);
          } else {
            Serializer? nonNullSerializer =
                _serializers[_extractElementType(e.runtimeType)];
            if (nonNullSerializer != null) {
              return nonNullSerializer.serializer(object);
            }
          }
        }
        throw StateError(
          'Element ${e.runtimeType} in List need to implement the Serializable interface',
        );
      }).toList();
    } else {
      Serializer? serializer = _serializers[S];
      if (serializer != null) {
        return serializer.serializer(object);
      } else {
        Serializer? nonNullSerializer = _serializers[_extractElementType(S)];
        if (nonNullSerializer != null) {
          return nonNullSerializer.serializer(object);
        }
      }
    }

    throw StateError(
      '${S.toString()} need to implement the Serializable interface',
    );
  }

  S deserialize<S>(dynamic data) {
    final Deserializer? deserializer = _deserializers[S];

    if (deserializer != null) {
      final targetData = (data is String && !_isPrimitiveDeserializer(S))
          ? jsonDecode(data)
          : data;
      return (deserializer as Deserializer<S>).deserializer(targetData);
    }

    if (S.isList) {
      final elementType = _extractElementType(S);
      final elementDeserializer = _deserializers[elementType];

      if (elementDeserializer != null) {
        final List rawList = data is String ? jsonDecode(data) : (data as List);
        return elementDeserializer.listDeserializer(rawList) as S;
      }
    }

    throw StateError('No deserializer found for type: <$S>');
  }

  /// Extrae el tipo E de un tipo List<E> buscando en los tipos registrados
  Type _extractElementType(Type type) {
    var cleanTypeName = type.toString();

    // 1. Si termina en '?', se lo removemos para obtener el tipo no-nullable (T? -> T)
    if (cleanTypeName.endsWith('?')) {
      cleanTypeName = cleanTypeName.substring(0, cleanTypeName.length - 1);
    }

    // 2. Si es una lista, extraemos lo que está dentro de List<...>
    if (cleanTypeName.startsWith('List<') && cleanTypeName.endsWith('>')) {
      cleanTypeName = cleanTypeName.substring(5, cleanTypeName.length - 1);
      // Por si acaso el tipo de adentro era nullable también (ej: List<User?>)
      if (cleanTypeName.endsWith('?')) {
        cleanTypeName = cleanTypeName.substring(0, cleanTypeName.length - 1);
      }
    }

    // 3. Buscamos el nombre limpio en tus mapas de registros
    final targetKey = _deserializers.keys.firstWhere(
      (k) => k.toString() == cleanTypeName,
      orElse: () => _serializers.keys.firstWhere(
        (k) => k.toString() == cleanTypeName,
        orElse: () => throw StateError(
          'No serializer/deserializer found for type: <$cleanTypeName>',
        ),
      ),
    );

    return targetKey;
  }

  bool _isPrimitiveDeserializer(Type type) {
    return _defaultDeserializers.any((element) => element.type == type);
  }
}

extension ListTypeExtension on Type {
  bool get isList => toString().startsWith('List<');
}
