import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../../winter.dart';

class Header {
  final String? name;

  const Header({
    this.name,
  });
}

bool processHeaderAnnotation(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
) {
  Header? header = singleParam.metadata
      .firstWhereOrNull(
        (metadata) => metadata.reflectee.runtimeType == Header,
      )
      ?.reflectee;
  if (header != null) {
    bool isRequired = !singleParam.isOptional;

    var defaultValue = singleParam.hasDefaultValue
        ? singleParam.defaultValue?.reflectee
        : null;

    String headerName =
        header.name ?? MirrorSystem.getName(singleParam.simpleName);

    extractor(RequestEntity request) => isRequired
        ? request.headers[headerName]
        : request.headers[headerName] ?? defaultValue;

    if (singleParam.isNamed) {
      namedArgumentsFunctions[singleParam.simpleName] = extractor;
    } else {
      positionalArgumentsFunctions.add(extractor);
    }
  }
  return header != null;
}
