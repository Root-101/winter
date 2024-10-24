import 'dart:convert';
import 'dart:mirrors';

import 'package:collection/collection.dart';

import 'object_mapper.dart';

class ObjectMapperImpl extends ObjectMapper {
  ClassMirror jsonSerializableMirror = reflectClass(WinterDeserializable);

  Map<Type, ToJsonParserFunction> defaultSerializer = {
    DateTime: (dynamic object) => (object as DateTime).toIso8601String(),
    Duration: (dynamic object) => (object as Duration).inMilliseconds,
    Uri: (dynamic object) => (object as Uri).toString(),
    RegExp: (dynamic object) => (object as RegExp).pattern,
    String: (dynamic object) => (object as String),
    num: (dynamic object) => (object as num),
    int: (dynamic object) => (object as int),
    double: (dynamic object) => (object as double),
    bool: (dynamic object) => (object as bool),
  };

  Map<Type, FromJsonParserFunction> defaultDeserializer = {
    DateTime: (dynamic value) => DateTime.parse(value.toString()),
    Duration: (dynamic value) =>
        Duration(milliseconds: int.parse(value.toString())),
    Uri: (dynamic value) => Uri.parse(value.toString()),
    RegExp: (dynamic value) => RegExp(value.toString()),
    String: (dynamic value) => value as String,
    num: (dynamic value) => num.parse(value.toString()),
    int: (dynamic value) => int.parse(value.toString()),
    double: (dynamic value) => double.parse(value.toString()),
    bool: (dynamic value) => bool.parse(value.toString()),
  };

  ObjectMapperImpl({
    super.namingStrategy,
    Map<Type, ToJsonParserFunction>? defaultSerializerOverride,
    Map<Type, FromJsonParserFunction>? defaultDeserializerOverride,
    super.prettyPrint,
  }) {
    defaultSerializer.addAll(defaultSerializerOverride ?? {});
    defaultDeserializer.addAll(defaultDeserializerOverride ?? {});
  }

  @override
  String serialize(dynamic object) {
    dynamic parsedObject = _toMap(object, {});

    if (parsedObject is String) {
      return parsedObject;
    }

    dynamic cleanedUpObject = parsedObject;

    // Beautify the JSON with indentation
    if (prettyPrint) {
      return JsonEncoder.withIndent('  ').convert(cleanedUpObject);
    } else {
      return jsonEncode(cleanedUpObject);
    }
  }

  dynamic cleanUpObject(dynamic parsedObject) {
    if (parsedObject is List) {
      return parsedObject.map((e) => cleanUpObject(e)).toList();
    } else if (parsedObject is Map) {
      return parsedObject.map((key, value) {
        return MapEntry(key.toString(), cleanUpObject(value));
      });
    } else {
      return parsedObject.toString();
    }
  }

  dynamic _toMap(dynamic object, Set<dynamic> seen) {
    if (object == null) {
      return object;
    }

    if (seen.contains(object)) {
      throw StateError('Circular reference detected');
    }

    if (object is WinterSerializer) {
      return object.toJson();
    } else if (object is List) {
      return object.map((e) => _toMap(e, seen)).toList();
    } else if (object is Map) {
      return object
          .map((key, val) => MapEntry(_toMap(key, seen), _toMap(val, seen)));
    } else if (defaultSerializer.containsKey(object.runtimeType)) {
      return defaultSerializer[object.runtimeType]!(object);
    } else if (object is Uri) {
      //URI has subclases that actually make the object, this way the search needs to be manual
      return defaultSerializer[Uri]!(object);
    } else if (object is RegExp) {
      //Same as Uri
      return defaultSerializer[RegExp]!(object);
    } else {
      seen.add(object);

      /// It's a normal object/class, use mirror to parse its internal fields
      var result = <String, dynamic>{};

      var objectMirror = reflect(object);
      var classMirror = objectMirror.type;

      ToJsonParserFunction? classParserFunction =
          _getToJsonParser(classMirror.metadata);
      if (classParserFunction != null) {
        return classParserFunction(object);
      }

      // If the class doesn't have a parser, do the default, iterate through all fields and parse them
      for (var declaration in classMirror.declarations.values) {
        if (declaration is VariableMirror && !declaration.isStatic) {
          var fieldName = _getFieldName(declaration);
          var fieldValue =
              objectMirror.getField(declaration.simpleName).reflectee;

          ToJsonParserFunction? classParserFunction =
              _getToJsonParser(declaration.metadata);
          if (classParserFunction != null) {
            result[fieldName] = classParserFunction(fieldValue);
          } else {
            result[fieldName] = _toMap(fieldValue, seen);
          }
        }
      }
      return result;
    }
  }

  ToJsonParserFunction? _getToJsonParser(List<InstanceMirror> metadata) {
    PropertyParser? propertyParserLv1 = metadata
        .firstWhereOrNull((element) => element.reflectee is PropertyParser)
        ?.reflectee as PropertyParser?;
    if (propertyParserLv1 != null) {
      return propertyParserLv1.toJsonParser;
    }

    ToJsonParser? propertyParserLv2 = metadata
        .firstWhereOrNull((element) => element.reflectee is ToJsonParser)
        ?.reflectee as ToJsonParser?;
    if (propertyParserLv2 != null) {
      return propertyParserLv2.parser;
    }
    return null;
  }

  // -------------------------- DESERIALIZE FUNCTION -------------------------- \\
  @override
  T deserialize<T>(String jsonString) {
    if (defaultDeserializer.containsKey(T)) {
      return defaultDeserializer[T]!(jsonString);
    }
    dynamic jsonObject = jsonDecode(jsonString);
    return _fromMap(jsonObject, T);
  }

  @override
  List<T> deserializeList<T>(String jsonString) {
    dynamic jsonObject = jsonDecode(jsonString);
    return _fromMap(jsonObject, List<T>).cast<T>();
  }

  @override
  Map<K, V> deserializeMap<K, V>(String jsonString) {
    dynamic jsonObject = jsonDecode(jsonString);
    return _fromMap(jsonObject, Map<K, V>).cast<K, V>();
  }

  dynamic _fromMap(dynamic json, Type targetType) {
    if (json == null) return null;
    if (targetType.toString().startsWith('dynamic')) {
      return json;
    }

    ClassMirror typeMirror = reflectClass(targetType);
    if (typeMirror.superinterfaces.contains(jsonSerializableMirror)) {
      //TODO: hacerlo como mismo se hace el de `_createEmptyInstance` y buscar todos los builders y eso
      return typeMirror.newInstance(Symbol('fromJson'), [json]).reflectee;
    } else if (json is List) {
      ClassMirror classMirror = reflectType(targetType) as ClassMirror;
      TypeMirror paramTypeMirror = classMirror.typeArguments.first;
      Type subType = paramTypeMirror.reflectedType;

      return json.map((item) => _fromMap(item, subType)).toList();
    } else if (defaultDeserializer.containsKey(targetType)) {
      return defaultDeserializer[targetType]!(json);
    } else if (targetType is Uri) {
      //URI has subclases that actually make the object, this way the search needs to be manual
      return defaultDeserializer[Uri]!(json);
    } else if (targetType is RegExp) {
      //Same as Uri
      return defaultDeserializer[RegExp]!(json);
    } else if (json is Map) {
      if (targetType.toString().startsWith('Map')) {
        Type keyType = reflectType(targetType).typeArguments[0].reflectedType;
        Type valueType = reflectType(targetType).typeArguments[1].reflectedType;

        return json.map((key, value) =>
            MapEntry(_fromMap(key, keyType), _fromMap(value, valueType)));
      }

      var classMirror = reflectClass(targetType);
      InstanceMirror emptyInstanceMirror = _createEmptyInstance(classMirror);

      for (var declaration in classMirror.declarations.values) {
        if (declaration is VariableMirror && !declaration.isStatic) {
          String fieldName = _getFieldName(declaration);

          if (json.containsKey(fieldName)) {
            FromJsonParserFunction? parserFunction =
                _getFromJsonParser(declaration.metadata);

            var fieldValue = json[fieldName];

            if (parserFunction != null) {
              fieldValue = parserFunction(fieldValue);
            } else {
              fieldValue = _fromMap(fieldValue, declaration.type.reflectedType);
            }

            if (fieldValue is List) {
              CastList? castListAnnotation = declaration.metadata
                  .firstWhereOrNull((element) => element.reflectee is CastList)
                  ?.reflectee as CastList?;

              TypeMirror fieldTypeMirror =
                  (declaration.type as ClassMirror).typeArguments.first;
              String listParam = fieldTypeMirror.reflectedType.toString();

              if (listParam == 'dynamic') {
                emptyInstanceMirror.setField(
                  declaration.simpleName,
                  fieldValue,
                );
                continue;
              } else if (castListAnnotation != null) {
                emptyInstanceMirror.setField(declaration.simpleName,
                    castListAnnotation.parser(fieldValue));
                continue;
              } else {
                String rawFieldName =
                    MirrorSystem.getName(declaration.simpleName);

                throw StateError(
                  'Cant parse List without know it\'s type at runtime. Try add `@CastList<$listParam>()` on `List<$listParam> $rawFieldName;`',
                );
              }
            } else if (fieldValue is Map) {
              CastMap? castMapAnnotation = declaration.metadata
                  .firstWhereOrNull((element) => element.reflectee is CastMap)
                  ?.reflectee as CastMap?;

              TypeMirror fieldFirstTypeMirror =
                  (declaration.type as ClassMirror).typeArguments.first;
              String firstMapParam =
                  fieldFirstTypeMirror.reflectedType.toString();

              TypeMirror fieldSecondTypeMirror =
                  (declaration.type as ClassMirror).typeArguments[1];
              String secondMapParam =
                  fieldSecondTypeMirror.reflectedType.toString();

              if (firstMapParam == 'dynamic' && secondMapParam == 'dynamic') {
                emptyInstanceMirror.setField(
                  declaration.simpleName,
                  fieldValue,
                );
                continue;
              } else if (castMapAnnotation != null) {
                emptyInstanceMirror.setField(declaration.simpleName,
                    castMapAnnotation.parser(fieldValue));
                continue;
              } else {
                TypeMirror fieldFirstTypeMirror =
                    (declaration.type as ClassMirror).typeArguments.first;
                String firstMapParam =
                    fieldFirstTypeMirror.reflectedType.toString();

                TypeMirror fieldSecondTypeMirror =
                    (declaration.type as ClassMirror).typeArguments[1];
                String secondMapParam =
                    fieldSecondTypeMirror.reflectedType.toString();

                String rawFieldName =
                    MirrorSystem.getName(declaration.simpleName);

                throw StateError(
                  'Cant parse Map without know it\'s type at runtime. Try add `@CastMap<$firstMapParam, $secondMapParam>()` on `Map<$firstMapParam, $secondMapParam> $rawFieldName;`',
                );
              }
            }

            emptyInstanceMirror.setField(declaration.simpleName, fieldValue);
          } else {
            ClassMirror classMirror = declaration.type as ClassMirror;
            List<TypeMirror> fieldTypeMirror = classMirror.typeArguments;
            String params = fieldTypeMirror
                .fold(
                  '',
                  (previousValue, reflectedType) =>
                      '$previousValue, ${reflectedType.toString()}',
                )
                .replaceFirst(',', '')
                .trim();

            if (params.isNotEmpty) {
              params = '<$params>';
            }

            String rawFieldName = MirrorSystem.getName(declaration.simpleName);

            throw StateError(
                'No value in map present for field: `${classMirror.reflectedType}$params $rawFieldName`');
          }
        }
      }

      return emptyInstanceMirror.reflectee;
    } else {
      throw StateError('No hay mapper para este tipo de dato');
    }
  }

  FromJsonParserFunction? _getFromJsonParser(List<InstanceMirror> metadata) {
    PropertyParser? propertyParserLv1 = metadata
        .firstWhereOrNull((element) => element.reflectee is PropertyParser)
        ?.reflectee as PropertyParser?;
    if (propertyParserLv1 != null) {
      return propertyParserLv1.fromJsonParser;
    }

    FromJsonParser? propertyParserLv2 = metadata
        .firstWhereOrNull((element) => element.reflectee is FromJsonParser)
        ?.reflectee as FromJsonParser?;
    if (propertyParserLv2 != null) {
      return propertyParserLv2.parser;
    }
    return null;
  }

  //--------------------------
  String _getFieldName(DeclarationMirror field) {
    JsonProperty? jsonPropAnnotation = field.metadata
        .firstWhereOrNull((element) => element.reflectee is JsonProperty)
        ?.reflectee as JsonProperty?;

    if (jsonPropAnnotation != null) {
      return jsonPropAnnotation.name;
    }

    String rawFieldName = MirrorSystem.getName(field.simpleName);
    return namingStrategy(rawFieldName);
  }

  InstanceMirror _createEmptyInstance(ClassMirror classMirror) {
    var constructors = classMirror.declarations.values.where((declaration) {
      return declaration is MethodMirror && declaration.isConstructor;
    });
    DeclarationMirror? fullEmpty = constructors.firstWhereOrNull((element) {
      MethodMirror mirror = element as MethodMirror;
      return MirrorSystem.getName((mirror).constructorName) == '' &&
          mirror.parameters.isEmpty;
    });
    DeclarationMirror? empty = constructors.firstWhereOrNull((element) {
      MethodMirror mirror = element as MethodMirror;
      return MirrorSystem.getName((mirror).constructorName) == 'empty' &&
          mirror.parameters.isEmpty;
    });
    if (fullEmpty != null) {
      return classMirror.newInstance(const Symbol(''), []);
    } else if (empty != null) {
      return classMirror.newInstance(const Symbol('empty'), []);
    } else {
      String className = MirrorSystem.getName(classMirror.simpleName);
      throw StateError(
        'Class $className need a $className() or an $className.empty() constructor',
      );
    }
  }
}
