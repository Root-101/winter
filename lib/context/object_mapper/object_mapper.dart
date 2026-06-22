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

  Deserializer(this.deserializer) : type = T {
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
    Serializer<DateTime?>((object) => object?.toIso8601String()),
    Serializer<Duration>((object) => object.inMilliseconds),
    Serializer<Duration?>((object) => object?.inMilliseconds),
    Serializer<Uri>((object) => object.toString()),
    Serializer<Uri?>((object) => object?.toString()),
    Serializer<RegExp>((object) => object.pattern),
    Serializer<RegExp?>((object) => object?.pattern),
    Serializer<String>((object) => object),
    Serializer<String?>((object) => object),
    Serializer<num>((object) => object),
    Serializer<num?>((object) => object),
    Serializer<int>((object) => object),
    Serializer<int?>((object) => object),
    Serializer<double>((object) => object),
    Serializer<double?>((object) => object),
    Serializer<bool>((object) => object),
    Serializer<bool?>((object) => object),
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
    //if primitive => serialize with defaults
    Serializer? serializer = _serializers[S];
    if (serializer != null) {
      return serializer.serializer(object);
    } else if (object is Serializable) {
      //if Serializable => serialize
      return object.toJson();
    } else if (object is List) {
      //if list, same:
      return object.map((e) {
        if (e is Map) {
          return e;
        }

        Serializer? serializer = _serializers[e.runtimeType];
        if (serializer != null) {
          //if element is primitive => serialize with defaults
          Object? obj = serializer.serializer(e);
          return obj;
        } else if (e is Serializable) {
          //if element is Serializable => serialize
          return e.toJson();
        } else {
          throw StateError(
            'Element ${e.runtimeType} in List need to implement the Serializable interface',
          );
        }
      }).toList();
    }

    throw StateError(
      '${S.toString()} need to implement the Serializable interface',
    );
  }

  S deserialize<S>(dynamic data) {
    Type type = S;
    Deserializer? deserializer = _deserializers[type];
    if (deserializer != null) {
      if (data is String) {
        if (_isPrimitiveDeserializer(type)) {
          return (deserializer as Deserializer<S>).deserializer(data);
        } else {
          return (deserializer as Deserializer<S>).deserializer(
            jsonDecode(data),
          );
        }
      } else {
        return (deserializer as Deserializer<S>).deserializer(data);
      }
    }
    throw StateError('No deserializer found for type: <${S.toString()}>');
  }

  bool _isPrimitiveDeserializer(Type type) {
    return _defaultDeserializers.any((element) => element.type == type);
  }

  List<S> deserializeList<S>(dynamic json) {
    return (json as List<dynamic>).map((e) => deserialize<S>(e)).toList();
  }
}
