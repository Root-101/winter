import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../../winter.dart';

class Body<T> {
  final Object Function(String body, ObjectMapper om) parser;

  const Body._(this.parser);

  const Body() : parser = plainBodyParser<T>;

  const Body.list() : parser = bodyListParser<T>;

  const Body.map() : parser = bodyMapParser<T>;
}

///internal parser/caster to plain Object (Wrapped to allow using generics)
PlainBodyWrapper<T> plainBodyParser<T>(String body, ObjectMapper om) =>
    PlainBodyWrapper(om.deserialize<T>(body));

///internal parser/caster to list
List<T> bodyListParser<T>(String body, ObjectMapper om) =>
    om.deserializeList<T>(body);

///internal parser/caster to map
Map<String, T> bodyMapParser<T>(String body, ObjectMapper om) =>
    om.deserializeMap<String, T>(body).cast<String, T>();

///wrapper around plain body to be able to use generic type
class PlainBodyWrapper<T> {
  final T body;

  PlainBodyWrapper(this.body);
}

bool processBodyAnnotation(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
  ObjectMapper om,
) {
  Body? body = singleParam.metadata
      .firstWhereOrNull(
        (metadata) => metadata.reflectee is Body,
      )
      ?.reflectee;
  if (body != null) {
    bool isRequired = !singleParam.isOptional;

    var defaultValue = singleParam.hasDefaultValue
        ? singleParam.defaultValue?.reflectee
        : null;

    extractor(RequestEntity request) async {
      String rawBody = await request.readAsString();
      if (!isRequired && rawBody.isEmpty) {
        return defaultValue;
      }
      Object parsedBody = body.parser(rawBody, om);
      if (parsedBody is PlainBodyWrapper) {
        return parsedBody.body;
      }
      return parsedBody;
    }

    if (singleParam.isNamed) {
      namedArgumentsFunctions[singleParam.simpleName] = extractor;
    } else {
      positionalArgumentsFunctions.add(extractor);
    }
  }
  return body != null;
}
