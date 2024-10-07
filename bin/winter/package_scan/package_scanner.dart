import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../winter.dart';

///Function used to extract a param, like the body or an header from a request
typedef ParamExtractor = dynamic Function(RequestEntity request);

Route? route() {
  ObjectMapper om = ObjectMapperImpl();

  // Obtener el MirrorSystem
  MirrorSystem mirrorSystem = currentMirrorSystem();

  // Iterar sobre todas las librerías cargadas
  for (var entry in mirrorSystem.libraries.entries) {
    final uri = entry.key;
    final libMirror = entry.value;
    if (uri.toString().contains('package_scan.dart')) {
      for (var entry2 in libMirror.declarations.entries) {
        final symbol = entry2.key;
        final declaration = entry2.value;
        if (declaration is MethodMirror) {
          MethodMirror methodMirror = declaration;
          RequestRoute? mapper = methodMirror.metadata
              .firstWhereOrNull(
                (metadata) => metadata.reflectee is RequestRoute,
              )
              ?.reflectee;
          if (mapper != null) {
            HttpMethod method = mapper.method;
            String path = mapper.path;

            List<ParamExtractor> positionalArgumentsFunctions = [];
            Map<Symbol, ParamExtractor> namedArgumentsFunctions = {};
            for (var singleParam in methodMirror.parameters) {
              bool paramSuccessfullyExtracted = extractParam(
                positionalArgumentsFunctions,
                namedArgumentsFunctions,
                singleParam,
                om,
              );

              if (!paramSuccessfullyExtracted) {
                throw StateError(
                    'Param ${MirrorSystem.getName(singleParam.simpleName)} '
                    'don\'t have any recognised annotation (or any at all)');
              }
            }

            return Route(
              path: path,
              method: method,
              handler: (request) async {
                List<dynamic> posArgs = [];
                for (var element in positionalArgumentsFunctions) {
                  posArgs.add(await element(request));
                }

                Map<Symbol, dynamic> namedArgs = {};
                for (var entry in namedArgumentsFunctions.entries) {
                  namedArgs[entry.key] = await entry.value(request);
                }

                return libMirror
                    .invoke(
                      methodMirror.simpleName,
                      posArgs,
                      namedArgs,
                    )
                    .reflectee;
              },
            );
          }
        } /*else if (declaration is ClassMirror) {
          // Verificar si la clase tiene la anotación MyAnnotation
          if (declaration.metadata.any(
              (metadata) => metadata.reflectee.runtimeType == RequestBody)) {
            print("Clase anotada encontrada: ${MirrorSystem.getName(symbol)}");
          }
        }*/
      }
    }
  }
  return null;
}

bool extractParam(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
  ObjectMapper om,
) {
  ///Process request body
  bool processedBody = _processRequestBody(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
    om,
  );

  ///Process request header
  bool processedHeader = _processRequestHeader(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
  );

  ///Process raw request entity
  bool processedRawRequest = _processRawRequest(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
  );

  ///Process path param
  bool processedPathParam = _processPathParam(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
  );

  ///Process query param
  bool processedQueryParam = _processQueryParam(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
  );

  return processedBody ||
      processedHeader ||
      processedRawRequest ||
      processedPathParam ||
      processedQueryParam;
}

bool _processRawRequest(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
) {
  bool isRequestEntity = singleParam.type.reflectedType == RequestEntity;

  if (isRequestEntity) {
    extractor(RequestEntity request) => request;

    if (singleParam.isNamed) {
      namedArgumentsFunctions[singleParam.simpleName] = extractor;
    } else {
      positionalArgumentsFunctions.add(extractor);
    }
  }
  return isRequestEntity;
}

bool _processRequestBody(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
  ObjectMapper om,
) {
  AbstractBody? body = singleParam.metadata
      .firstWhereOrNull(
        (metadata) => metadata.reflectee is AbstractBody,
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
      return body.parser(rawBody, om);
    }

    if (singleParam.isNamed) {
      namedArgumentsFunctions[singleParam.simpleName] = extractor;
    } else {
      positionalArgumentsFunctions.add(extractor);
    }
  }
  return body != null;
}

bool _processRequestHeader(
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

bool _processPathParam(
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

bool _processQueryParam(
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
