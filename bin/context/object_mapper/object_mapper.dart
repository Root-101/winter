import 'package:change_case/change_case.dart';

//-------------------- default impl of to/from json --------------------\\
abstract class WinterSerializer {
  Map toJson() {
    throw UnimplementedError('toJson() is not implemented');
  }
}

abstract class WinterDeserializable {
  factory WinterDeserializable.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('fromJson() is not implemented');
  }
}

//-------------------- default impl of to/from json --------------------\\
//-------------------------- naming --------------------------\\
typedef NamingStrategy = String Function(String value);

class JsonProperty {
  final String name;

  const JsonProperty(this.name);
}

//-------------------------- naming --------------------------\\
//-------------------------- parser --------------------------\\
///Definicion de funcion para hacer el parseo de un json a un objeto
typedef FromJsonParserFunction = dynamic Function(dynamic property);

///Definicion de funcion para hacer el parseo de un objeto a un json
typedef ToJsonParserFunction = dynamic Function(dynamic property);

///Definicion de funcion para hacer el casteo de: List<dynamic> a List<T>
typedef ListParserFunction<T> = List<T> Function(List property);

///Definicion de funcion para hacer el casteo de: Map<dynamic> a Map<T>
typedef MapParserFunction<K, V> = Map<K, V> Function(Map property);

///Annotation con ambas funciones from-json y to-json
class PropertyParser {
  final FromJsonParserFunction fromJsonParser;
  final ToJsonParserFunction toJsonParser;

  const PropertyParser(this.fromJsonParser, this.toJsonParser);
}

///Annotation para personalizar el parsea a un objeto a un json
class FromJsonParser {
  final FromJsonParserFunction parser;

  const FromJsonParser(this.parser);
}

///Annotation para personalizar el parsea a un json de un objeto
class ToJsonParser {
  final ToJsonParserFunction parser;

  const ToJsonParser(this.parser);
}

///Annotation para obtener el tipo T de una lista y hacerle el parser
class CastList<T> {
  final ListParserFunction<T> parser;

  const CastList() : parser = listCaster;
}

///funcion por defecto para hacer el parser de una List<dynamic> a List<T>
List<T> listCaster<T>(List list) => list.cast<T>();

///Annotation para obtener el tipo T de un map y hacerle el parser
class CastMap<K, V> {
  final MapParserFunction<K, V> parser;

  const CastMap() : parser = mapCaster;
}

///funcion por defecto para hacer el parser de una List<dynamic> a List<T>
Map<K, V> mapCaster<K, V>(Map map) => map.cast<K, V>();
//-------------------------- parser --------------------------\\

abstract class ObjectMapper {
  late final NamingStrategy namingStrategy;
  late final bool prettyPrint;

  ObjectMapper({
    NamingStrategy? namingStrategy,
    this.prettyPrint = true,
  }) {
    this.namingStrategy = namingStrategy ?? NamingStrategies.basic;
  }

  String serialize(dynamic object);

  T deserialize<T>(String jsonString);

  List<T> deserializeList<T>(String jsonString);

  Map<K, V> deserializeMap<K, V>(String jsonString);
}

class NamingStrategies {
  // Example: "exampleString" -> "exampleString"
  static NamingStrategy get basic => (String value) => value;

  // Example: "exampleString" -> "example_string"
  static NamingStrategy get snakeCase => (String value) => value.toSnakeCase();

  // Example: "exampleString" -> "exampleString"
  static NamingStrategy camelCase = (String value) => value.toCamelCase();

  // Example: "exampleString" -> "ExampleString"
  static NamingStrategy pascalCase = (String value) => value.toPascalCase();

  // Example: "exampleString" -> "example-string"
  static NamingStrategy kebabCase = (String value) => value.toKebabCase();

  // Example: "exampleString" -> "example.string"
  static NamingStrategy dotCase = (String value) => value.toDotCase();

  // Example: "exampleString" -> "example/string"
  static NamingStrategy pathCase = (String value) => value.toPathCase();

  // Example: "exampleString" -> "EXAMPLE_STRING"
  static NamingStrategy constantCase = (String value) => value.toConstantCase();

  // Example: "exampleString" -> "Example-String"
  static NamingStrategy headerCase = (String value) => value.toHeaderCase();

  // Example: "exampleString" -> "Example string"
  static NamingStrategy sentenceCase = (String value) => value.toSentenceCase();

  // Example: "exampleString" -> "Example String"
  static NamingStrategy titleCase = (String value) => value.toTitleCase();

  // Example: "ExampleString" -> "eXAMPLEsTRING"
  static NamingStrategy swapCase = (String value) => value.toSwapCase();

  // Example: "exampleString" -> "EXAMPLESTRING"
  static NamingStrategy upperCase = (String value) => value.toUpperCase();

  // Example: "exampleString" -> "examplestring"
  static NamingStrategy lowerCase = (String value) => value.toLowerCase();
}
