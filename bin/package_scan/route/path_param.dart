import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../../winter.dart';

///NOTE: path-param dont support optional type
class PathParam {
  final String? name;

  const PathParam({
    this.name,
  });
}

bool processPathParamAnnotation(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
) {
  PathParam? pathParam = singleParam.metadata
      .firstWhereOrNull(
        (metadata) => metadata.reflectee.runtimeType == PathParam,
      )
      ?.reflectee;
  if (pathParam != null) {
    if (singleParam.isOptional) {
      throw StateError(
        '@PathParam needs to be a required field '
        '(If not it could mess up the navigation and give some unexpected 404).'
        '\nFailed Field: ${MirrorSystem.getName(singleParam.simpleName)}',
      );
    }
    String paramName =
        pathParam.name ?? MirrorSystem.getName(singleParam.simpleName);

    extractor(RequestEntity request) => request.pathParams[paramName];

    if (singleParam.isNamed) {
      namedArgumentsFunctions[singleParam.simpleName] = extractor;
    } else {
      positionalArgumentsFunctions.add(extractor);
    }
  }
  return pathParam != null;
}
