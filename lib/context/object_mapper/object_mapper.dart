import 'dart:io';

abstract class Serializable {
  Object? toJson();
}

class Serializer<T> {
  final Type type;
  final Object? Function(T object) serializer;

  Serializer(this.serializer) : type = T {
    if (type.toString() == 'dynamic') {
      stderr.writeln(
        '\n'
        'WARNING: Unable to infer Serializer type. '
        'The serializer was registered as "dynamic", which usually happens when '
        'the generic type argument is omitted. '
        'Declare it explicitly, for example: '
        'Serializer<YOUR-EXPLICIT-TYPE>((object) => object.toJson())'
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
      stderr.writeln(
        '\n'
        'WARNING: Unable to infer Deserializer type. '
        'The deserializer was registered as "dynamic", which usually happens when '
        'the generic type argument is omitted. '
        'Declare it explicitly, for example: '
        'Deserializer<YOUR-EXPLICIT-TYPE>((object) => object.toJson())'
        '\n',
      );
    }
  }
}

abstract class ObjectMapper {
  Object? serialize<S>(S object);

  S deserialize<S>(dynamic data);

  Object? serializeList<S>(List<S> objects);

  List<S> deserializeList<S>(dynamic json);

  void addSerializer<S>(Serializer<S> serializer);

  void removeSerializer<S>();

  void addDeserializer<S>(Deserializer<S> deserializer);

  void removeDeserializer<S>();
}

class ObjectMapperImpl extends ObjectMapper {
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

  ObjectMapperImpl({
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

  @override
  Object? serialize<S>(S object) {
    if (object is Serializable) {
      return object.toJson();
    }
    Type type = S;
    Serializer? serializer = _serializers[type];
    if (serializer != null) {
      return (serializer as Serializer<S>).serializer(object);
    }
    throw StateError('No serializer found for type: <${S.toString()}>');
  }

  @override
  S deserialize<S>(dynamic data) {
    Type type = S;
    Deserializer? deserializer = _deserializers[type];
    if (deserializer != null) {
      return (deserializer as Deserializer<S>).deserializer(data);
    }
    throw StateError('No deserializer found for type: <${S.toString()}>');
  }

  @override
  Object? serializeList<S>(List<S> objects) {
    return objects.map((e) => serialize<S>(e)).toList();
  }

  @override
  List<S> deserializeList<S>(dynamic json) {
    return (json as List<dynamic>).map((e) => deserialize<S>(e)).toList();
  }

  @override
  void addSerializer<S>(Serializer<S> serializer) {
    _serializers[serializer.type] = serializer;
  }

  @override
  void removeSerializer<S>() {
    _serializers.remove(S);
  }

  @override
  void addDeserializer<S>(Deserializer<S> deserializer) {
    _deserializers[deserializer.type] = deserializer;
  }

  @override
  void removeDeserializer<S>() {
    _deserializers.remove(S);
  }
}
