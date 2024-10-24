import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../../winter.dart';

class QueryParam {
  final String? name;

  const QueryParam({
    this.name,
  });
}

bool processQueryParamAnnotation(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
) {
  QueryParam? queryParam = singleParam.metadata
      .firstWhereOrNull(
        (metadata) => metadata.reflectee.runtimeType == QueryParam,
      )
      ?.reflectee;
  if (queryParam != null) {
    bool isRequired = !singleParam.isOptional;

    var defaultValue = singleParam.hasDefaultValue
        ? singleParam.defaultValue?.reflectee
        : null;

    String paramName =
        queryParam.name ?? MirrorSystem.getName(singleParam.simpleName);

    extractor(RequestEntity request) => isRequired
        ? request.queryParams[paramName]
        : request.queryParams[paramName] ?? defaultValue;

    if (singleParam.isNamed) {
      namedArgumentsFunctions[singleParam.simpleName] = extractor;
    } else {
      positionalArgumentsFunctions.add(extractor);
    }
  }
  return queryParam != null;
}
